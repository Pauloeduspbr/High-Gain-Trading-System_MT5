//+------------------------------------------------------------------+
//|                                             SolarWindsJoy_MT5.mq5 |
//|                              Converted from MT4 by GitHub Copilot |
//|                                              MT5 Compatible Version |
//+------------------------------------------------------------------+

#property copyright "Solar Winds Joy - MT5 conversion"
#property version   "1.00"

#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   5

#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrLimeGreen
#property indicator_width1  2
#property indicator_label1  "Positive Histogram"

#property indicator_type2   DRAW_HISTOGRAM
#property indicator_color2  clrRed
#property indicator_width2  2
#property indicator_label2  "Negative Histogram"

#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGold
#property indicator_width3  2
#property indicator_label3  "Signal Line"

#property indicator_type4   DRAW_LINE
#property indicator_color4  clrLimeGreen
#property indicator_width4  2
#property indicator_label4  "Positive Line"

#property indicator_type5   DRAW_LINE
#property indicator_color5  clrRed
#property indicator_width5  2
#property indicator_label5  "Negative Line"

//--- Input parameters
input int period = 35;      // Fisher Transform Period
input int smooth = 10;      // Smoothing Period

//--- Indicator buffers
double histogramPos[];      // Positive histogram
double histogramNeg[];      // Negative histogram
double signalLine[];        // Main signal line
double positiveLine[];      // Positive trend line
double negativeLine[];      // Negative trend line
double fisherRaw[];         // Raw Fisher Transform (calculation)
double fisherSignal[];      // Fisher signal values (calculation)  
double smoothedSignal[];    // Smoothed signal (calculation)

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set indicator buffers
   SetIndexBuffer(0, histogramPos, INDICATOR_DATA);
   SetIndexBuffer(1, histogramNeg, INDICATOR_DATA);
   SetIndexBuffer(2, signalLine, INDICATOR_DATA);
   SetIndexBuffer(3, positiveLine, INDICATOR_DATA);
   SetIndexBuffer(4, negativeLine, INDICATOR_DATA);
   SetIndexBuffer(5, fisherRaw, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, fisherSignal, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, smoothedSignal, INDICATOR_CALCULATIONS);
   
   //--- Set indicator properties
   IndicatorSetString(INDICATOR_SHORTNAME, "Solar Winds Joy MT5 (" + 
                     IntegerToString(period) + "," + IntegerToString(smooth) + ")");
   
   //--- Set arrays as series
   ArraySetAsSeries(histogramPos, true);
   ArraySetAsSeries(histogramNeg, true);
   ArraySetAsSeries(signalLine, true);
   ArraySetAsSeries(positiveLine, true);
   ArraySetAsSeries(negativeLine, true);
   ArraySetAsSeries(fisherRaw, true);
   ArraySetAsSeries(fisherSignal, true);
   ArraySetAsSeries(smoothedSignal, true);
   
   //--- Set empty values
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   return(INIT_SUCCEEDED);
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
   if(rates_total < period + smooth)
      return(0);
      
   //--- Set arrays as series
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   //--- Calculate Fisher Transform values
   double value1 = 0, fish1 = 0;
   
   for(int i = rates_total - 1; i >= 0; i--)
   {
      int pos = rates_total - 1 - i; // Convert to series index
      
      //--- Find highest and lowest in period
      int lookback = MathMin(period, pos + 1);
      double maxH = high[ArrayMaximum(high, pos, lookback)];
      double minL = low[ArrayMinimum(low, pos, lookback)];
      
      //--- Calculate normalized price
      double price = (high[pos] + low[pos]) / 2.0;
      
      //--- Avoid division by zero
      double range = maxH - minL;
      double value = 0;
      
      if(range > 0)
      {
         value = 0.33 * 2.0 * ((price - minL) / range - 0.5) + 0.67 * value1;
      }
      else
      {
         // When range is zero, maintain previous value
         value = 0.67 * value1;
      }
      
      value = MathMax(MathMin(value, 0.999), -0.999);
      
      //--- Calculate Fisher Transform with protection against invalid values
      if(MathAbs(value) < 0.999)
      {
         fisherRaw[pos] = 0.5 * MathLog((1.0 + value) / (1.0 - value)) + 0.5 * fish1;
      }
      else
      {
         // Handle extreme values
         fisherRaw[pos] = 0.5 * fish1;
      }
      
      //--- Generate signal values
      if(fisherRaw[pos] > 0)
         fisherSignal[pos] = 10;
      else
         fisherSignal[pos] = -10;
         
      //--- Store for next iteration
      value1 = value;
      fish1 = fisherRaw[pos];
   }
   
   //--- Apply first smoothing (forward)
   for(int i = rates_total - 1; i >= 0; i--)
   {
      int pos = rates_total - 1 - i;
      
      double sum = 0, sumw = 0;
      
      for(int k = 0; k < smooth && (pos + k) < rates_total; k++)
      {
         double weight = smooth - k;
         sumw += weight;
         sum += weight * fisherSignal[pos + k];
      }
      
      if(sumw != 0)
         smoothedSignal[pos] = sum / sumw;
      else
         smoothedSignal[pos] = 0;
   }
   
   //--- Apply second smoothing (backward) and fill final buffers
   for(int i = 0; i < rates_total; i++)
   {
      int pos = i;
      
      double sum = 0, sumw = 0;
      
      for(int k = 0; k < smooth && (pos - k) >= 0; k++)
      {
         double weight = smooth - k;
         sumw += weight;
         sum += weight * smoothedSignal[pos - k];
      }
      
      double finalValue;
      if(sumw != 0)
         finalValue = sum / sumw;
      else
         finalValue = 0;
         
      //--- Fill buffers based on signal direction
      signalLine[pos] = finalValue;
      
      //--- Initialize all buffers
      histogramPos[pos] = EMPTY_VALUE;
      histogramNeg[pos] = EMPTY_VALUE;
      positiveLine[pos] = EMPTY_VALUE;
      negativeLine[pos] = EMPTY_VALUE;
      
      //--- Fill appropriate buffers
      if(finalValue > 0)
      {
         positiveLine[pos] = finalValue;
         histogramPos[pos] = finalValue;
      }
      else if(finalValue < 0)
      {
         negativeLine[pos] = finalValue;
         histogramNeg[pos] = finalValue;
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Get current signal direction for EA usage                       |
//+------------------------------------------------------------------+
int GetSignalDirection(int shift = 0)
{
   if(shift >= ArraySize(signalLine))
      return(0);
      
   double value = signalLine[shift];
   
   if(value > 0)
      return(1);   // Bullish
   else if(value < 0)
      return(-1);  // Bearish
   else
      return(0);   // Neutral
}

//+------------------------------------------------------------------+
//| Get signal strength for EA usage                                |
//+------------------------------------------------------------------+
double GetSignalStrength(int shift = 0)
{
   if(shift >= ArraySize(signalLine))
      return(0);
      
   return(MathAbs(signalLine[shift]));
}

//+------------------------------------------------------------------+
//| Check for signal change                                         |
//+------------------------------------------------------------------+
bool IsSignalChange(int shift = 0)
{
   if(shift + 1 >= ArraySize(signalLine))
      return(false);
      
   int currentSignal = GetSignalDirection(shift);
   int previousSignal = GetSignalDirection(shift + 1);
   
   return(currentSignal != previousSignal && currentSignal != 0);
}

//+------------------------------------------------------------------+
//| Get raw Fisher Transform value                                  |
//+------------------------------------------------------------------+
double GetFisherValue(int shift = 0)
{
   if(shift >= ArraySize(fisherRaw))
      return(0);
      
   return(fisherRaw[shift]);
}
