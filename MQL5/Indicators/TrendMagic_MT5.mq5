//+------------------------------------------------------------------+
//|                                                TrendMagic_MT5.mq5 |
//|                              Converted from MT4 by GitHub Copilot |
//|                                              MT5 Compatible Version |
//+------------------------------------------------------------------+

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_width1  2
#property indicator_label1  "Trend Up"

#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_width2  2
#property indicator_label2  "Trend Down"

//--- Input parameters
input int CCI_Period = 50;     // CCI Period
input int ATR_Period = 5;      // ATR Period

//--- Indicator buffers
double bufferUp[];
double bufferDn[];

//--- Indicator handles
int cci_handle;
int atr_handle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set indicator buffers
   SetIndexBuffer(0, bufferUp, INDICATOR_DATA);
   SetIndexBuffer(1, bufferDn, INDICATOR_DATA);
   
   //--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   //--- Create indicator handles
   cci_handle = iCCI(_Symbol, PERIOD_CURRENT, CCI_Period, PRICE_TYPICAL);
   atr_handle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   
   if(cci_handle == INVALID_HANDLE || atr_handle == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles");
      return(INIT_FAILED);
   }
   
   //--- Set indicator properties
   IndicatorSetString(INDICATOR_SHORTNAME, "TrendMagic MT5 (" + 
                     IntegerToString(CCI_Period) + "," + 
                     IntegerToString(ATR_Period) + ")");
   
   //--- Set array as series
   ArraySetAsSeries(bufferUp, true);
   ArraySetAsSeries(bufferDn, true);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   if(cci_handle != INVALID_HANDLE)
      IndicatorRelease(cci_handle);
   if(atr_handle != INVALID_HANDLE)
      IndicatorRelease(atr_handle);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   //--- Check for minimum bars
   if(rates_total < CCI_Period + ATR_Period)
      return(0);
      
   //--- Set arrays as series
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   //--- Get CCI and ATR values
   double cci_values[];
   double atr_values[];
   
   ArraySetAsSeries(cci_values, true);
   ArraySetAsSeries(atr_values, true);
   
   int copy_bars = rates_total - prev_calculated + 1;
   if(prev_calculated == 0)
      copy_bars = rates_total;
   
   if(CopyBuffer(cci_handle, 0, 0, copy_bars, cci_values) <= 0)
      return(0);
   if(CopyBuffer(atr_handle, 0, 0, copy_bars, atr_values) <= 0)
      return(0);
   
   //--- Calculate starting position
   int start = prev_calculated;
   if(start == 0)
      start = 1;
   
   //--- Main calculation loop
   for(int i = start; i < rates_total; i++)
   {
      int pos = rates_total - 1 - i; // Convert to series index
      
      double thisCCI = cci_values[pos];
      double lastCCI = (pos + 1 < ArraySize(cci_values)) ? cci_values[pos + 1] : 0;
      double atr_val = atr_values[pos];
      
      //--- Initialize buffers
      bufferUp[pos] = EMPTY_VALUE;
      bufferDn[pos] = EMPTY_VALUE;
      
      //--- Handle trend changes
      if(thisCCI >= 0 && lastCCI < 0)
      {
         if(pos + 1 < rates_total && bufferDn[pos + 1] != EMPTY_VALUE)
            bufferUp[pos + 1] = bufferDn[pos + 1];
      }
      
      if(thisCCI <= 0 && lastCCI > 0)
      {
         if(pos + 1 < rates_total && bufferUp[pos + 1] != EMPTY_VALUE)
            bufferDn[pos + 1] = bufferUp[pos + 1];
      }
      
      //--- Calculate trend lines
      if(thisCCI >= 0)
      {
         bufferUp[pos] = low[pos] - atr_val;
         if(pos + 1 < rates_total && bufferUp[pos + 1] != EMPTY_VALUE)
         {
            if(bufferUp[pos] < bufferUp[pos + 1])
               bufferUp[pos] = bufferUp[pos + 1];
         }
      }
      else
      {
         if(thisCCI <= 0)
         {
            bufferDn[pos] = high[pos] + atr_val;
            if(pos + 1 < rates_total && bufferDn[pos + 1] != EMPTY_VALUE)
            {
               if(bufferDn[pos] > bufferDn[pos + 1])
                  bufferDn[pos] = bufferDn[pos + 1];
            }
         }
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Get trend direction for EA usage                                 |
//+------------------------------------------------------------------+
int GetTrendDirection(int shift = 0)
{
   if(shift >= ArraySize(bufferUp) || shift >= ArraySize(bufferDn))
      return(0);
      
   if(bufferUp[shift] != EMPTY_VALUE)
      return(1);  // Bullish trend
   else if(bufferDn[shift] != EMPTY_VALUE)  
      return(-1); // Bearish trend
   else
      return(0);  // No trend
}

//+------------------------------------------------------------------+
//| Get trend line value for EA usage                               |
//+------------------------------------------------------------------+
double GetTrendValue(int shift = 0)
{
   if(shift >= ArraySize(bufferUp) || shift >= ArraySize(bufferDn))
      return(0);
      
   if(bufferUp[shift] != EMPTY_VALUE)
      return(bufferUp[shift]);
   else if(bufferDn[shift] != EMPTY_VALUE)
      return(bufferDn[shift]);
   else
      return(0);
}
