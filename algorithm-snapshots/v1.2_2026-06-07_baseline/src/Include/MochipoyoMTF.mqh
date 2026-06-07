//+------------------------------------------------------------------+
//| MochipoyoMTF.mqh - マルチタイムフレーム データ取得ヘルパー        |
//+------------------------------------------------------------------+
#ifndef __MOCHIPOYO_MTF_MQH__
#define __MOCHIPOYO_MTF_MQH__

// ハンドル保持構造体
struct MTFHandles
{
   int ema20_h4;  int ema30_h4;  int ema40_h4;
   int ema20_m15; int ema30_m15; int ema40_m15;
   int ema20_m5;  int ema30_m5;  int ema40_m5;
   int macd_h4;   int macd_m15;  int macd_m5;
};

MTFHandles g_mtf;

//+------------------------------------------------------------------+
//| ハンドル初期化                                                    |
//+------------------------------------------------------------------+
bool MTF_Init(const string symbol)
{
   g_mtf.ema20_h4  = iMA(symbol, PERIOD_H4,  20, 0, MODE_EMA, PRICE_CLOSE);
   g_mtf.ema30_h4  = iMA(symbol, PERIOD_H4,  30, 0, MODE_EMA, PRICE_CLOSE);
   g_mtf.ema40_h4  = iMA(symbol, PERIOD_H4,  40, 0, MODE_EMA, PRICE_CLOSE);
   g_mtf.ema20_m15 = iMA(symbol, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE);
   g_mtf.ema30_m15 = iMA(symbol, PERIOD_M15, 30, 0, MODE_EMA, PRICE_CLOSE);
   g_mtf.ema40_m15 = iMA(symbol, PERIOD_M15, 40, 0, MODE_EMA, PRICE_CLOSE);
   g_mtf.ema20_m5  = iMA(symbol, PERIOD_M5,  20, 0, MODE_EMA, PRICE_CLOSE);
   g_mtf.ema30_m5  = iMA(symbol, PERIOD_M5,  30, 0, MODE_EMA, PRICE_CLOSE);
   g_mtf.ema40_m5  = iMA(symbol, PERIOD_M5,  40, 0, MODE_EMA, PRICE_CLOSE);
   g_mtf.macd_h4   = iMACD(symbol, PERIOD_H4,  12, 26, 9, PRICE_CLOSE);
   g_mtf.macd_m15  = iMACD(symbol, PERIOD_M15, 12, 26, 9, PRICE_CLOSE);
   g_mtf.macd_m5   = iMACD(symbol, PERIOD_M5,  12, 26, 9, PRICE_CLOSE);

   int handles[] = {g_mtf.ema20_h4,g_mtf.ema30_h4,g_mtf.ema40_h4,
                    g_mtf.ema20_m15,g_mtf.ema30_m15,g_mtf.ema40_m15,
                    g_mtf.ema20_m5,g_mtf.ema30_m5,g_mtf.ema40_m5,
                    g_mtf.macd_h4,g_mtf.macd_m15,g_mtf.macd_m5};
   for(int i=0;i<ArraySize(handles);i++)
   {
      if(handles[i]==INVALID_HANDLE)
      {
         Print("MTF_Init: ハンドル取得失敗 index=",i);
         return(false);
      }
   }
   return(true);
}

//+------------------------------------------------------------------+
//| ハンドル解放                                                      |
//+------------------------------------------------------------------+
void MTF_Deinit()
{
   int handles[] = {g_mtf.ema20_h4,g_mtf.ema30_h4,g_mtf.ema40_h4,
                    g_mtf.ema20_m15,g_mtf.ema30_m15,g_mtf.ema40_m15,
                    g_mtf.ema20_m5,g_mtf.ema30_m5,g_mtf.ema40_m5,
                    g_mtf.macd_h4,g_mtf.macd_m15,g_mtf.macd_m5};
   for(int i=0;i<ArraySize(handles);i++)
      if(handles[i]!=INVALID_HANDLE) IndicatorRelease(handles[i]);
}

//+------------------------------------------------------------------+
//| 指定EMAハンドル取得                                               |
//+------------------------------------------------------------------+
int GetEMAHandle(ENUM_TIMEFRAMES tf, int period)
{
   if(tf==PERIOD_H4)
   {
      if(period==20) return g_mtf.ema20_h4;
      if(period==30) return g_mtf.ema30_h4;
      if(period==40) return g_mtf.ema40_h4;
   }
   else if(tf==PERIOD_M15)
   {
      if(period==20) return g_mtf.ema20_m15;
      if(period==30) return g_mtf.ema30_m15;
      if(period==40) return g_mtf.ema40_m15;
   }
   else if(tf==PERIOD_M5)
   {
      if(period==20) return g_mtf.ema20_m5;
      if(period==30) return g_mtf.ema30_m5;
      if(period==40) return g_mtf.ema40_m5;
   }
   return INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| MACDハンドル取得                                                  |
//+------------------------------------------------------------------+
int GetMACDHandle(ENUM_TIMEFRAMES tf)
{
   if(tf==PERIOD_H4)  return g_mtf.macd_h4;
   if(tf==PERIOD_M15) return g_mtf.macd_m15;
   if(tf==PERIOD_M5)  return g_mtf.macd_m5;
   return INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| EMA値取得                                                         |
//+------------------------------------------------------------------+
double GetEMA(const string symbol, ENUM_TIMEFRAMES tf, int period, int shift)
{
   int h = GetEMAHandle(tf, period);
   if(h==INVALID_HANDLE) return 0.0;
   double buf[];
   if(CopyBuffer(h, 0, shift, 1, buf) <= 0) return 0.0;
   return buf[0];
}

//+------------------------------------------------------------------+
//| MACD main/signal取得                                              |
//+------------------------------------------------------------------+
bool GetMACD(const string symbol, ENUM_TIMEFRAMES tf, int shift, double &mainVal, double &sigVal)
{
   int h = GetMACDHandle(tf);
   if(h==INVALID_HANDLE) return false;
   double bm[], bs[];
   if(CopyBuffer(h, 0, shift, 1, bm) <= 0) return false;
   if(CopyBuffer(h, 1, shift, 1, bs) <= 0) return false;
   mainVal = bm[0];
   sigVal  = bs[0];
   return true;
}

//+------------------------------------------------------------------+
//| 価格取得ヘルパー                                                  |
//+------------------------------------------------------------------+
double GetClose(const string symbol, ENUM_TIMEFRAMES tf, int shift)
{ return iClose(symbol, tf, shift); }

double GetHigh(const string symbol, ENUM_TIMEFRAMES tf, int shift)
{ return iHigh(symbol, tf, shift); }

double GetLow(const string symbol, ENUM_TIMEFRAMES tf, int shift)
{ return iLow(symbol, tf, shift); }

#endif // __MOCHIPOYO_MTF_MQH__
