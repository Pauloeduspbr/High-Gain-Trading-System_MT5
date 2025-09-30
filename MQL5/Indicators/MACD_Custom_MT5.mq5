//+------------------------------------------------------------------+
//|                                            MACD_Custom_MT5.mq5  |
//|                              Converted from MT4 by GitHub Copilot |
//|                                     Custom MACD with Histogram   |
//+------------------------------------------------------------------+

#property copyright "MACD Custom MT5"
#property version   "1.00"
#property description "MACD with custom parameters and histogram"

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   3

#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_width1  1
#property indicator_label1  "MACD Main"

#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_width2  1
#property indicator_label2  "MACD Signal"

#property indicator_type3   DRAW_HISTOGRAM
#property indicator_color3  clrGray
#property indicator_width3  2
#property indicator_label3  "MACD Histogram"

//--- Input parameters
input int    FastEMA = 12;           // Fast EMA Period
input int    SlowEMA = 26;           // Slow EMA Period
input int    SignalSMA = 9;          // Signal SMA Period
input ENUM_APPLIED_PRICE AppliedPrice = PRICE_CLOSE; // Applied Price

//--- Indicator buffers
double macdBuffer[];
double signalBuffer[];
double histogramBuffer[];
double tempBuffer[];

//--- Global variables
int macd_handle;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, macdBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, signalBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, histogramBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, tempBuffer, INDICATOR_CALCULATIONS);
   
   ArraySetAsSeries(macdBuffer, true);
   ArraySetAsSeries(signalBuffer, true);
   ArraySetAsSeries(histogramBuffer, true);
   
   macd_handle = iMACD(_Symbol, PERIOD_CURRENT, FastEMA, SlowEMA, SignalSMA, AppliedPrice);
   if(macd_handle == INVALID_HANDLE)
      return(INIT_FAILED);
   
   IndicatorSetString(INDICATOR_SHORTNAME, "MACD Custom (" + 
                     IntegerToString(FastEMA) + "," + IntegerToString(SlowEMA) + "," + IntegerToString(SignalSMA) + ")");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(macd_handle != INVALID_HANDLE)
      IndicatorRelease(macd_handle);
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < MathMax(FastEMA, SlowEMA) + SignalSMA)
      return(0);
   
   double macd_main[], macd_signal[];
   ArraySetAsSeries(macd_main, true);
   ArraySetAsSeries(macd_signal, true);
   
   if(CopyBuffer(macd_handle, 0, 0, rates_total, macd_main) <= 0 ||
      CopyBuffer(macd_handle, 1, 0, rates_total, macd_signal) <= 0)
      return(0);
   
   int start = (prev_calculated == 0) ? MathMax(FastEMA, SlowEMA) + SignalSMA : prev_calculated - 1;
   
   for(int i = start; i < rates_total; i++)
   {
      int pos = rates_total - 1 - i;
      
      if(pos >= ArraySize(macd_main) || pos >= ArraySize(macd_signal))
         continue;
         
      macdBuffer[pos] = macd_main[pos];
      signalBuffer[pos] = macd_signal[pos];
      histogramBuffer[pos] = macd_main[pos] - macd_signal[pos];
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
double GetMACDMain(int shift = 0)
{
   return (shift < ArraySize(macdBuffer)) ? macdBuffer[shift] : 0;
}

//+------------------------------------------------------------------+
double GetMACDSignal(int shift = 0)
{
   return (shift < ArraySize(signalBuffer)) ? signalBuffer[shift] : 0;
}

//+------------------------------------------------------------------+
double GetMACDHistogram(int shift = 0)
{
   return (shift < ArraySize(histogramBuffer)) ? histogramBuffer[shift] : 0;
}

//+------------------------------------------------------------------+
bool IsMACDBullish(int shift = 0)
{
   if(shift + 1 >= ArraySize(histogramBuffer)) return false;
   return (histogramBuffer[shift] > 0 && histogramBuffer[shift] > histogramBuffer[shift + 1]);
}

//+------------------------------------------------------------------+
bool IsMACDBearish(int shift = 0)
{
   if(shift + 1 >= ArraySize(histogramBuffer)) return false;
   return (histogramBuffer[shift] < 0 && histogramBuffer[shift] < histogramBuffer[shift + 1]);
}
