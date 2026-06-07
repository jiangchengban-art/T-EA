//+------------------------------------------------------------------+
//|                                                  MochipoyoEA.mq5 |
//|                           もちぽよ手法 MT5 フル自動売買EA         |
//+------------------------------------------------------------------+
#property copyright "Mochipoyo EA"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Mochipoyo\MochipoyoMTF.mqh>
#include <Mochipoyo\MochipoyoSignal.mqh>
#include <Mochipoyo\MochipoyoRisk.mqh>

//+------------------------------------------------------------------+
//| 入力パラメーター                                                  |
//+------------------------------------------------------------------+
input double InpRiskPercent     = 1.0;      // 1トレードリスク%
input double InpMinRR           = 1.0;      // 最小RR比
input double InpTargetRR        = 1.2;      // ターゲットRR比
input int    InpMinScore        = 8;        // 最小合計スコア(12点満点)
input int    InpMagicNumber     = 20260411;
input int    InpMaxSpreadPoints = 50;       // 最大許容スプレッド(ポイント)
input int    InpSlippagePoints  = 20;
input string InpNewsAvoidHours  = "";       // 例:"Mon21:30-22:30;Wed15:00-15:30"
input bool   InpEnableTrading   = true;     // 自動売買ON/OFF
input int    InpBufferPips      = 5;        // 損切バッファ(pips)
input bool   InpTrailByEMA40    = false;    // EMA40トレーリング

//+------------------------------------------------------------------+
//| グローバル                                                        |
//+------------------------------------------------------------------+
CTrade   g_trade;
datetime g_lastBarTime = 0;
string   g_symbol;

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   g_symbol = _Symbol;
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpSlippagePoints);
   g_trade.SetTypeFilling(ORDER_FILLING_IOC);

   if(!MTF_Init(g_symbol))
   {
      Print("MTF_Init 失敗");
      return(INIT_FAILED);
   }
   if(InpRiskPercent<=0 || InpTargetRR<InpMinRR)
   {
      Print("入力パラメーター不正");
      return(INIT_PARAMETERS_INCORRECT);
   }
   PrintFormat("MochipoyoEA init OK symbol=%s magic=%d", g_symbol, InpMagicNumber);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   MTF_Deinit();
}

//+------------------------------------------------------------------+
//| 新M15バー検出                                                     |
//+------------------------------------------------------------------+
bool IsNewM15Bar()
{
   datetime t = iTime(g_symbol, PERIOD_M15, 0);
   if(t==0) return false;
   if(t!=g_lastBarTime)
   {
      g_lastBarTime = t;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| トレーリング: EMA40追従                                           |
//+------------------------------------------------------------------+
void TrailByEMA40()
{
   if(!InpTrailByEMA40) return;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      string sym = PositionGetSymbol(i);
      if(sym!=g_symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double ema40 = GetEMA(g_symbol, PERIOD_M15, 40, 0);
      if(ema40<=0) continue;
      double pip = PipSize(g_symbol);
      double buf = InpBufferPips * pip;
      if(StringFind(g_symbol,"XAU")>=0) buf = 0.5;
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      if(type==POSITION_TYPE_BUY)
      {
         double newSL = ema40 - buf;
         if(newSL > sl && newSL < PositionGetDouble(POSITION_PRICE_CURRENT))
            g_trade.PositionModify(ticket, newSL, tp);
      }
      else if(type==POSITION_TYPE_SELL)
      {
         double newSL = ema40 + buf;
         if((sl==0 || newSL < sl) && newSL > PositionGetDouble(POSITION_PRICE_CURRENT))
            g_trade.PositionModify(ticket, newSL, tp);
      }
   }
}

//+------------------------------------------------------------------+
//| エントリー試行                                                    |
//+------------------------------------------------------------------+
void TryEntry(bool isLong)
{
   int score = 0;
   string reasons[];
   EvaluateEntry(g_symbol, isLong, score, reasons);

   PrintFormat("--- %s %s 評価 score=%d ---", g_symbol, isLong?"LONG":"SHORT", score);
   for(int i=0; i<ArraySize(reasons); i++) Print("  ",reasons[i]);

   if(score < InpMinScore) { Print("  -> スコア不足"); return; }

   // 必須: 非レンジ(M15)
   if(!IsNotRange(g_symbol, PERIOD_M15)) { Print("  -> レンジ棄却"); return; }

   // エントリー価格
   double price = isLong ? SymbolInfoDouble(g_symbol, SYMBOL_ASK)
                         : SymbolInfoDouble(g_symbol, SYMBOL_BID);
   double sl = GetStopLossPrice(g_symbol, isLong, InpBufferPips);
   if(sl<=0) { Print("  -> SL算出失敗"); return; }

   // RR比チェック
   double slDist = MathAbs(price - sl);
   if(isLong && sl>=price) { Print("  -> SL位置不正"); return; }
   if(!isLong && sl<=price) { Print("  -> SL位置不正"); return; }

   double tp = GetTakeProfitPrice(price, sl, isLong, InpTargetRR);
   double rr = MathAbs(tp-price) / slDist;
   if(rr < InpMinRR) { Print("  -> RR不足 rr=",rr); return; }

   double lot = CalculateLotSize(g_symbol, InpRiskPercent, slDist);
   if(lot<=0) { Print("  -> ロット0"); return; }

   int digits = (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   bool ok;
   if(isLong) ok = g_trade.Buy(lot, g_symbol, price, sl, tp, "Mochipoyo");
   else       ok = g_trade.Sell(lot, g_symbol, price, sl, tp, "Mochipoyo");
   if(ok)
      PrintFormat("  -> ENTRY %s lot=%.2f sl=%.5f tp=%.5f rr=%.2f",
                  isLong?"BUY":"SELL", lot, sl, tp, rr);
   else
      PrintFormat("  -> ORDER失敗 ret=%d", g_trade.ResultRetcode());
}

//+------------------------------------------------------------------+
//| OnTick                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!InpEnableTrading) return;

   TrailByEMA40();

   if(!IsNewM15Bar()) return;

   // ゲート
   if(IsNewsTime(InpNewsAvoidHours)) { Print("ニュース時間スキップ"); return; }
   if(!IsSpreadOK(g_symbol, InpMaxSpreadPoints)) { Print("スプレッド超過スキップ"); return; }
   if(HasOpenPosition(g_symbol, InpMagicNumber)) return;

   TryEntry(true);
   if(HasOpenPosition(g_symbol, InpMagicNumber)) return;
   TryEntry(false);
}
//+------------------------------------------------------------------+
