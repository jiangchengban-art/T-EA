//+------------------------------------------------------------------+
//| MochipoyoSignal.mqh - シグナル判定・RCI・ダイバージェンス         |
//+------------------------------------------------------------------+
#ifndef __MOCHIPOYO_SIGNAL_MQH__
#define __MOCHIPOYO_SIGNAL_MQH__

#include "MochipoyoMTF.mqh"

#define RCI_THRESHOLD 60.0

//+------------------------------------------------------------------+
//| RCI計算（順位-時間相関 * 100）                                    |
//| 時間順位: 新しい方から 1,2,...,n                                   |
//| 価格順位: 高値が1位                                                |
//+------------------------------------------------------------------+
double CalculateRCI(const string symbol, ENUM_TIMEFRAMES tf, int period, int shift)
{
   if(period < 2) return 0.0;
   double price[];
   ArrayResize(price, period);
   for(int i=0; i<period; i++)
      price[i] = iClose(symbol, tf, shift + i); // 0=直近(shift)
   // 時間順位: index 0 を1位(最新)、index period-1 を period位
   // 価格順位: 値の大きいものから1位。同値は平均順位
   double priceRank[];
   ArrayResize(priceRank, period);
   for(int i=0; i<period; i++)
   {
      double rank = 1.0;
      int same = 0;
      for(int j=0; j<period; j++)
      {
         if(i==j) continue;
         if(price[j] > price[i]) rank += 1.0;
         else if(price[j] == price[i]) same++;
      }
      // 同値のとき平均順位補正
      priceRank[i] = rank + (double)same / 2.0;
   }
   double sumD2 = 0.0;
   for(int i=0; i<period; i++)
   {
      double timeRank = (double)(i + 1);
      double d = priceRank[i] - timeRank;
      sumD2 += d*d;
   }
   double denom = (double)period * ((double)period*(double)period - 1.0);
   if(denom == 0.0) return 0.0;
   double rci = (1.0 - 6.0*sumD2/denom) * 100.0;
   return rci;
}

//+------------------------------------------------------------------+
//| EMAパーフェクトオーダー判定                                       |
//+------------------------------------------------------------------+
bool IsPerfectOrderUp(const string symbol, ENUM_TIMEFRAMES tf)
{
   double e20_0 = GetEMA(symbol, tf, 20, 0);
   double e30_0 = GetEMA(symbol, tf, 30, 0);
   double e40_0 = GetEMA(symbol, tf, 40, 0);
   double e20_3 = GetEMA(symbol, tf, 20, 3);
   double e30_3 = GetEMA(symbol, tf, 30, 3);
   double e40_3 = GetEMA(symbol, tf, 40, 3);
   if(e20_0==0.0 || e30_0==0.0 || e40_0==0.0) return false;
   bool order = (e20_0 > e30_0) && (e30_0 > e40_0);
   bool slope = (e20_0 > e20_3) && (e30_0 > e30_3) && (e40_0 > e40_3);
   return order && slope;
}

bool IsPerfectOrderDown(const string symbol, ENUM_TIMEFRAMES tf)
{
   double e20_0 = GetEMA(symbol, tf, 20, 0);
   double e30_0 = GetEMA(symbol, tf, 30, 0);
   double e40_0 = GetEMA(symbol, tf, 40, 0);
   double e20_3 = GetEMA(symbol, tf, 20, 3);
   double e30_3 = GetEMA(symbol, tf, 30, 3);
   double e40_3 = GetEMA(symbol, tf, 40, 3);
   if(e20_0==0.0 || e30_0==0.0 || e40_0==0.0) return false;
   bool order = (e20_0 < e30_0) && (e30_0 < e40_0);
   bool slope = (e20_0 < e20_3) && (e30_0 < e30_3) && (e40_0 < e40_3);
   return order && slope;
}

//+------------------------------------------------------------------+
//| スイング高安検出（N本法）                                         |
//| leftRight=3: その足が左右3本より高い(低い)ならスイング高(安)     |
//+------------------------------------------------------------------+
bool FindSwingHighs(const string symbol, ENUM_TIMEFRAMES tf, int lookback, int leftRight,
                    double &h1, int &idx1, double &h2, int &idx2)
{
   h1=h2=0.0; idx1=idx2=-1;
   int found = 0;
   for(int i=leftRight; i<lookback && found<2; i++)
   {
      double hi = iHigh(symbol, tf, i);
      bool isHigh = true;
      for(int k=1; k<=leftRight; k++)
      {
         if(iHigh(symbol, tf, i-k) >= hi || iHigh(symbol, tf, i+k) >= hi)
         {
            isHigh = false; break;
         }
      }
      if(isHigh)
      {
         if(found==0) { h1=hi; idx1=i; }
         else         { h2=hi; idx2=i; }
         found++;
         i += leftRight; // 近接回避
      }
   }
   return (found>=2);
}

bool FindSwingLows(const string symbol, ENUM_TIMEFRAMES tf, int lookback, int leftRight,
                   double &l1, int &idx1, double &l2, int &idx2)
{
   l1=l2=0.0; idx1=idx2=-1;
   int found = 0;
   for(int i=leftRight; i<lookback && found<2; i++)
   {
      double lo = iLow(symbol, tf, i);
      bool isLow = true;
      for(int k=1; k<=leftRight; k++)
      {
         if(iLow(symbol, tf, i-k) <= lo || iLow(symbol, tf, i+k) <= lo)
         {
            isLow = false; break;
         }
      }
      if(isLow)
      {
         if(found==0) { l1=lo; idx1=i; }
         else         { l2=lo; idx2=i; }
         found++;
         i += leftRight;
      }
   }
   return (found>=2);
}

//+------------------------------------------------------------------+
//| ダウ理論判定                                                      |
//+------------------------------------------------------------------+
bool IsHigherHighHigherLow(const string symbol, ENUM_TIMEFRAMES tf, int lookback)
{
   double h1,h2,l1,l2; int ih1,ih2,il1,il2;
   if(!FindSwingHighs(symbol, tf, lookback, 3, h1, ih1, h2, ih2)) return false;
   if(!FindSwingLows (symbol, tf, lookback, 3, l1, il1, l2, il2)) return false;
   // h1が新しい方、h2が古い方
   return (h1 > h2) && (l1 > l2);
}

bool IsLowerHighLowerLow(const string symbol, ENUM_TIMEFRAMES tf, int lookback)
{
   double h1,h2,l1,l2; int ih1,ih2,il1,il2;
   if(!FindSwingHighs(symbol, tf, lookback, 3, h1, ih1, h2, ih2)) return false;
   if(!FindSwingLows (symbol, tf, lookback, 3, l1, il1, l2, il2)) return false;
   return (h1 < h2) && (l1 < l2);
}

//+------------------------------------------------------------------+
//| ヒドゥンダイバージェンス                                          |
//| Bullish: 価格の安値=切り上げ, MACDの安値=切り下げ                  |
//| Bearish: 価格の高値=切り下げ, MACDの高値=切り上げ                  |
//+------------------------------------------------------------------+
bool HasHiddenBullishDiv(const string symbol, ENUM_TIMEFRAMES tf)
{
   double l1,l2; int i1,i2;
   if(!FindSwingLows(symbol, tf, 60, 3, l1, i1, l2, i2)) return false;
   double m1,s1,m2,s2;
   if(!GetMACD(symbol, tf, i1, m1, s1)) return false;
   if(!GetMACD(symbol, tf, i2, m2, s2)) return false;
   // i1が新しい安値 > i2古い安値（価格切り上げ）
   // MACD: m1 < m2（切り下げ）
   return (l1 > l2) && (m1 < m2);
}

bool HasHiddenBearishDiv(const string symbol, ENUM_TIMEFRAMES tf)
{
   double h1,h2; int i1,i2;
   if(!FindSwingHighs(symbol, tf, 60, 3, h1, i1, h2, i2)) return false;
   double m1,s1,m2,s2;
   if(!GetMACD(symbol, tf, i1, m1, s1)) return false;
   if(!GetMACD(symbol, tf, i2, m2, s2)) return false;
   return (h1 < h2) && (m1 > m2);
}

//+------------------------------------------------------------------+
//| グランビル反発判定                                                |
//| 直近数本で High/Low が EMA20〜EMA40帯にタッチ、現終値が離脱       |
//+------------------------------------------------------------------+
bool IsGranvilleBounceUp(const string symbol, ENUM_TIMEFRAMES tf)
{
   double e20 = GetEMA(symbol, tf, 20, 0);
   double e40 = GetEMA(symbol, tf, 40, 0);
   if(e20==0.0 || e40==0.0) return false;
   double upper = MathMax(e20, e40);
   double lower = MathMin(e20, e40);
   bool touched = false;
   for(int i=1; i<=5; i++)
   {
      double lo = iLow(symbol, tf, i);
      if(lo <= upper && lo >= lower - (upper-lower)*0.2) { touched = true; break; }
   }
   double close0 = iClose(symbol, tf, 0);
   return touched && (close0 > upper);
}

bool IsGranvilleBounceDown(const string symbol, ENUM_TIMEFRAMES tf)
{
   double e20 = GetEMA(symbol, tf, 20, 0);
   double e40 = GetEMA(symbol, tf, 40, 0);
   if(e20==0.0 || e40==0.0) return false;
   double upper = MathMax(e20, e40);
   double lower = MathMin(e20, e40);
   bool touched = false;
   for(int i=1; i<=5; i++)
   {
      double hi = iHigh(symbol, tf, i);
      if(hi >= lower && hi <= upper + (upper-lower)*0.2) { touched = true; break; }
   }
   double close0 = iClose(symbol, tf, 0);
   return touched && (close0 < lower);
}

//+------------------------------------------------------------------+
//| 非レンジ判定: EMA20とEMA40の乖離がATR換算で十分か                  |
//+------------------------------------------------------------------+
bool IsNotRange(const string symbol, ENUM_TIMEFRAMES tf)
{
   double e20 = GetEMA(symbol, tf, 20, 0);
   double e40 = GetEMA(symbol, tf, 40, 0);
   if(e20==0.0 || e40==0.0) return false;
   double diff = MathAbs(e20 - e40);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   // 価格の0.05%を最小乖離とするシンプル判定
   double minDiff = iClose(symbol, tf, 0) * 0.0005;
   return diff > minDiff;
}

//+------------------------------------------------------------------+
//| ラウンドナンバー接近（簡易）                                      |
//+------------------------------------------------------------------+
bool IsNearRoundNumber(const string symbol, bool isLong)
{
   double price = SymbolInfoDouble(symbol, SYMBOL_BID);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double step;
   if(digits>=3 && digits<=5 && StringFind(symbol,"JPY")<0) step = 0.0050; // 50pip
   else if(StringFind(symbol,"JPY")>=0) step = 0.50;                        // 50銭
   else step = 5.0;                                                         // GOLD
   double nearest = MathRound(price/step)*step;
   double dist = MathAbs(price - nearest);
   return dist < step*0.3;
}

//+------------------------------------------------------------------+
//| 統合エントリー評価                                                |
//+------------------------------------------------------------------+
int EvaluateEntry(const string symbol, bool isLong, int &score, string &reasons[])
{
   score = 0;
   ArrayResize(reasons, 0);

   // 1. 上位足トレンド(2点)
   bool htfOK = isLong ? IsHigherHighHigherLow(symbol, PERIOD_H4, 80)
                       : IsLowerHighLowerLow  (symbol, PERIOD_H4, 80);
   if(htfOK) { score += 2; ArrayResize(reasons, ArraySize(reasons)+1); reasons[ArraySize(reasons)-1] = "[OK+2] 1.H4トレンド"; }
   else       { ArrayResize(reasons, ArraySize(reasons)+1); reasons[ArraySize(reasons)-1] = "[--] 1.H4トレンド"; }

   // 2. 下位足トレンド一致(2点)
   bool ltfOK = isLong ? (IsHigherHighHigherLow(symbol, PERIOD_M15, 60) && IsHigherHighHigherLow(symbol, PERIOD_M5, 60))
                       : (IsLowerHighLowerLow  (symbol, PERIOD_M15, 60) && IsLowerHighLowerLow  (symbol, PERIOD_M5, 60));
   if(ltfOK) { score += 2; ArrayResize(reasons, ArraySize(reasons)+1); reasons[ArraySize(reasons)-1] = "[OK+2] 2.M15/M5一致"; }
   else       { ArrayResize(reasons, ArraySize(reasons)+1); reasons[ArraySize(reasons)-1] = "[--] 2.M15/M5一致"; }

   // 3. EMAパーフェクトオーダー(1点) M15で判定
   bool poOK = isLong ? IsPerfectOrderUp(symbol, PERIOD_M15) : IsPerfectOrderDown(symbol, PERIOD_M15);
   if(poOK) { score += 1; ArrayResize(reasons, ArraySize(reasons)+1); reasons[ArraySize(reasons)-1] = "[OK+1] 3.PO(M15)"; }
   else      { ArrayResize(reasons, ArraySize(reasons)+1); reasons[ArraySize(reasons)-1] = "[--] 3.PO(M15)"; }

   // 4. グランビル反発(1点) M5
   bool gvOK = isLong ? IsGranvilleBounceUp(symbol, PERIOD_M5) : IsGranvilleBounceDown(symbol, PERIOD_M5);
   if(gvOK) { score += 1; ArrayResize(reasons, ArraySize(reasons)+1); reasons[ArraySize(reasons)-1] = "[OK+1] 4.Granville"; }
   else      { ArrayResize(reasons, ArraySize(reasons)+1); reasons[ArraySize(reasons)-1] = "[--] 4.Granville"; }

   // 5. RCI過熱域(2点) M5
   double rci9  = CalculateRCI(symbol, PERIOD_M5, 9,  0);
   double rci14 = CalculateRCI(symbol, PERIOD_M5, 14, 0);
   double rci18 = CalculateRCI(symbol, PERIOD_M5, 18, 0);
   bool rciHeat = isLong ? (rci9 <= -RCI_THRESHOLD || rci14 <= -RCI_THRESHOLD || rci18 <= -RCI_THRESHOLD)
                         : (rci9 >=  RCI_THRESHOLD || rci14 >=  RCI_THRESHOLD || rci18 >=  RCI_THRESHOLD);
   if(rciHeat) { score += 2; ArrayResize(reasons, ArraySize(reasons)+1); reasons[ArraySize(reasons)-1] = "[OK+2] 5.RCI過熱"; }
   else         { ArrayResize(reasons, ArraySize(reasons)+1); reasons[ArraySize(reasons)-1] = "[--] 5.RCI過熱"; }

   // 6. RCI反転(1点) M5 RCI9 前足との比較
   double rci9_1 = CalculateRCI(symbol, PERIOD_M5, 9, 1);
   bool rciRev = isLong ? (rci9 > rci9_1 && rci9_1 <= -RCI_THRESHOLD)
                        : (rci9 < rci9_1 && rci9_1 >=  RCI_THRESHOLD);
   if(rciRev) { score += 1; ArrayResize(reasons, ArraySize(reasons)+1); reasons[ArraySize(reasons)-1] = "[OK+1] 6.RCI反転"; }
   else        { ArrayResize(reasons, ArraySize(reasons)+1); reasons[ArraySize(reasons)-1] = "[--] 6.RCI反転"; }

   // 7. ヒドゥンダイバージェンス(2点) M15
   bool hdOK = isLong ? HasHiddenBullishDiv(symbol, PERIOD_M15) : HasHiddenBearishDiv(symbol, PERIOD_M15);
   if(hdOK) { score += 2; ArrayResize(reasons, ArraySize(reasons)+1); reasons[ArraySize(reasons)-1] = "[OK+2] 7.ヒドゥン"; }
   else      { ArrayResize(reasons, ArraySize(reasons)+1); reasons[ArraySize(reasons)-1] = "[--] 7.ヒドゥン"; }

   // 8. ラウンドナンバー接近(1点)
   if(IsNearRoundNumber(symbol, isLong)) { score += 1; ArrayResize(reasons, ArraySize(reasons)+1); reasons[ArraySize(reasons)-1] = "[OK+1] 8.RoundNumber"; }
   else                                   { ArrayResize(reasons, ArraySize(reasons)+1); reasons[ArraySize(reasons)-1] = "[--] 8.RoundNumber"; }

   return score;
}

#endif // __MOCHIPOYO_SIGNAL_MQH__
