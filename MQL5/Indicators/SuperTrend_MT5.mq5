//+------------------------------------------------------------------+
//|                                               SuperTrend_MT5.mq5 |
//|                              Converted from MT4 by GitHub Copilot |
//|                                        SuperTrend Indicator MT5   |
//+------------------------------------------------------------------+

#property copyright "SuperTrend MT5"
#property version   "1.00"
#property description "ATR based SuperTrend indicator"

#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLime
#property indicator_width1  2
#property indicator_label1  "SuperTrend Up"

#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_width2  2
#property indicator_label2  "SuperTrend Down"

//--- Input parameters
input int    ATR_Period = 10;        // ATR Period
input double ATR_Multiplier = 3.0;   // ATR Multiplier

//--- Indicator buffers
double upTrendBuffer[];
double downTrendBuffer[];
double trendDirectionBuffer[];
double atrBuffer[];

//--- Global variables
int atr_handle;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, upTrendBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, downTrendBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, trendDirectionBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, atrBuffer, INDICATOR_CALCULATIONS);
   
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   ArraySetAsSeries(upTrendBuffer, true);
   ArraySetAsSeries(downTrendBuffer, true);
   ArraySetAsSeries(trendDirectionBuffer, true);
   ArraySetAsSeries(atrBuffer, true);
   
   atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   if(atr_handle == INVALID_HANDLE)
      return(INIT_FAILED);
   
   IndicatorSetString(INDICATOR_SHORTNAME, "SuperTrend MT5 (" + 
                     IntegerToString(ATR_Period) + "," + DoubleToString(ATR_Multiplier, 1) + ")");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(atr_handle != INVALID_HANDLE)
      IndicatorRelease(atr_handle);
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
   if(rates_total < ATR_Period + 1)
      return(0);
      
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   double atr_values[];
   ArraySetAsSeries(atr_values, true);
   
   if(CopyBuffer(atr_handle, 0, 0, rates_total, atr_values) <= 0)
      return(0);
   
   int start = (prev_calculated == 0) ? ATR_Period : prev_calculated - 1;
   
   for(int i = start; i < rates_total; i++)
   {
      int pos = rates_total - 1 - i;
      
      if(pos >= ArraySize(atr_values)) continue;
      
      double hl2 = (high[pos] + low[pos]) / 2.0;
      double atr_val = atr_values[pos] * ATR_Multiplier;
      
      double basic_upper = hl2 + atr_val;
      double basic_lower = hl2 - atr_val;
      
      // Calculate final upper and lower bands
      double final_upper = basic_upper;
      double final_lower = basic_lower;
      
      if(pos + 1 < rates_total)
      {
         double prev_final_upper = (upTrendBuffer[pos + 1] != EMPTY_VALUE) ? 
                                  upTrendBuffer[pos + 1] : basic_upper;
         double prev_final_lower = (downTrendBuffer[pos + 1] != EMPTY_VALUE) ?
                                  downTrendBuffer[pos + 1] : basic_lower;
                                  
         final_upper = (basic_upper < prev_final_upper || close[pos + 1] > prev_final_upper) ?
                      basic_upper : prev_final_upper;
         final_lower = (basic_lower > prev_final_lower || close[pos + 1] < prev_final_lower) ?
                      basic_lower : prev_final_lower;
      }
      
      // Determine trend direction
      double trend = (pos + 1 < rates_total) ? trendDirectionBuffer[pos + 1] : 1;
      
      if(close[pos] <= final_lower)
         trend = -1;
      else if(close[pos] >= final_upper)
         trend = 1;
         
      trendDirectionBuffer[pos] = trend;
      
      // Set buffer values
      upTrendBuffer[pos] = EMPTY_VALUE;
      downTrendBuffer[pos] = EMPTY_VALUE;
      
      if(trend == 1)
         upTrendBuffer[pos] = final_lower;
      else
         downTrendBuffer[pos] = final_upper;
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
int GetTrendDirection(int shift = 0)
{
   return (shift < ArraySize(trendDirectionBuffer)) ? (int)trendDirectionBuffer[shift] : 0;
}

//+------------------------------------------------------------------+
double GetSuperTrendValue(int shift = 0)
{
   if(shift >= ArraySize(upTrendBuffer)) return 0;
   
   return (upTrendBuffer[shift] != EMPTY_VALUE) ? upTrendBuffer[shift] : downTrendBuffer[shift];
}
