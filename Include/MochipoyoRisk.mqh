//+------------------------------------------------------------------+
//| MochipoyoRisk.mqh - リスク・ロット・損益管理                      |
//+------------------------------------------------------------------+
#ifndef __MOCHIPOYO_RISK_MQH__
#define __MOCHIPOYO_RISK_MQH__

#include "MochipoyoMTF.mqh"
#include "MochipoyoSignal.mqh"

//+------------------------------------------------------------------+
//| 1 pip の価格単位                                                  |
//+------------------------------------------------------------------+
double PipSize(const string symbol)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(StringFind(symbol,"XAU")>=0) return point*10.0; // GOLDは0.1
   if(digits==3 || digits==5) return point*10.0;
   return point;
}

//+------------------------------------------------------------------+
//| ロット計算                                                        |
//+------------------------------------------------------------------+
double CalculateLotSize(const string symbol, double riskPercent, double slDistance)
{
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskCash = balance * riskPercent / 100.0;
   double tickVal  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal<=0 || tickSize<=0 || slDistance<=0) return 0.0;
   double lossPerLot = (slDistance / tickSize) * tickVal;
   if(lossPerLot<=0) return 0.0;
   double lot = riskCash / lossPerLot;
   double volMin  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double volMax  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double volStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot/volStep)*volStep;
   if(lot < volMin) lot = volMin;
   if(lot > volMax) lot = volMax;
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| 損切り価格: 直近スイング±バッファ、EMA40を補助に採用              |
//+------------------------------------------------------------------+
double GetStopLossPrice(const string symbol, bool isLong, int bufferPips)
{
   double pip = PipSize(symbol);
   if(StringFind(symbol,"XAU")>=0) pip = 0.1; // GOLD=0.1$刻み
   double buf = bufferPips * pip;
   if(StringFind(symbol,"XAU")>=0) buf = 0.5; // GOLD固定0.5

   double ema40 = GetEMA(symbol, PERIOD_M15, 40, 0);
   if(isLong)
   {
      double l1,l2; int i1,i2;
      double swingLow = 0.0;
      if(FindSwingLows(symbol, PERIOD_M15, 40, 3, l1, i1, l2, i2))
         swingLow = l1;
      double sl1 = (swingLow>0.0) ? swingLow - buf : 0.0;
      double sl2 = (ema40>0.0) ? ema40 - buf : 0.0;
      // 遠い方（安全）を採用
      if(sl1==0.0) return sl2;
      if(sl2==0.0) return sl1;
      return MathMin(sl1, sl2);
   }
   else
   {
      double h1,h2; int i1,i2;
      double swingHigh = 0.0;
      if(FindSwingHighs(symbol, PERIOD_M15, 40, 3, h1, i1, h2, i2))
         swingHigh = h1;
      double sl1 = (swingHigh>0.0) ? swingHigh + buf : 0.0;
      double sl2 = (ema40>0.0) ? ema40 + buf : 0.0;
      if(sl1==0.0) return sl2;
      if(sl2==0.0) return sl1;
      return MathMax(sl1, sl2);
   }
}

//+------------------------------------------------------------------+
//| 利確価格                                                          |
//+------------------------------------------------------------------+
double GetTakeProfitPrice(double entry, double sl, bool isLong, double targetRR)
{
   double dist = MathAbs(entry - sl);
   if(isLong)  return entry + dist*targetRR;
   else        return entry - dist*targetRR;
}

//+------------------------------------------------------------------+
//| 同一シンボル&マジックのポジション存在チェック                      |
//+------------------------------------------------------------------+
bool HasOpenPosition(const string symbol, long magic)
{
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      string sym = PositionGetSymbol(i);
      if(sym==symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC)==magic) return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| スプレッドチェック                                                |
//+------------------------------------------------------------------+
bool IsSpreadOK(const string symbol, int maxPoints)
{
   long sp = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   return (sp <= maxPoints);
}

//+------------------------------------------------------------------+
//| ニュース時間回避                                                  |
//| 形式: "Mon21:30-22:30;Wed15:00-15:30"                              |
//+------------------------------------------------------------------+
int DayNameToInt(const string s)
{
   if(s=="Sun") return 0;
   if(s=="Mon") return 1;
   if(s=="Tue") return 2;
   if(s=="Wed") return 3;
   if(s=="Thu") return 4;
   if(s=="Fri") return 5;
   if(s=="Sat") return 6;
   return -1;
}

bool IsNewsTime(const string avoidHours)
{
   if(StringLen(avoidHours)==0) return false;
   MqlDateTime cur;
   TimeToStruct(TimeCurrent(), cur);
   int curMin = cur.hour*60 + cur.min;
   int curDow = cur.day_of_week;

   string entries[];
   int n = StringSplit(avoidHours, ';', entries);
   for(int i=0; i<n; i++)
   {
      string e = entries[i];
      if(StringLen(e) < 12) continue;
      string dow = StringSubstr(e, 0, 3);
      int dowI = DayNameToInt(dow);
      if(dowI<0 || dowI!=curDow) continue;
      string rest = StringSubstr(e, 3);
      string parts[];
      if(StringSplit(rest, '-', parts)!=2) continue;
      string p1[], p2[];
      if(StringSplit(parts[0], ':', p1)!=2) continue;
      if(StringSplit(parts[1], ':', p2)!=2) continue;
      int sm = (int)StringToInteger(p1[0])*60 + (int)StringToInteger(p1[1]);
      int em = (int)StringToInteger(p2[0])*60 + (int)StringToInteger(p2[1]);
      if(curMin >= sm && curMin <= em) return true;
   }
   return false;
}

#endif // __MOCHIPOYO_RISK_MQH__
