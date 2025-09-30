//+------------------------------------------------------------------+
//|                                                      xb4d_MT5.mq5 |
//|                              Converted from MT4 by GitHub Copilot |
//|                                              MT5 Compatible Version |
//+------------------------------------------------------------------+

#property copyright "xbox forex - MT5 conversion"
#property link      "http://community.strangled.net"
#property version   "1.00"

#property indicator_separate_window
#property indicator_buffers 6
#property indicator_plots   3

#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrBlack
#property indicator_width1  2
#property indicator_label1  "Main"

#property indicator_type2   DRAW_HISTOGRAM
#property indicator_color2  clrBlue
#property indicator_width2  2
#property indicator_label2  "Positive"

#property indicator_type3   DRAW_HISTOGRAM
#property indicator_color3  clrRed
#property indicator_width3  2
#property indicator_label3  "Negative"

//--- Input parameters
input int    period = 27;           // Period
input int    offset = 0;            // Offset
input bool   EnableAlerts = true;   // Enable Alerts
input bool   EnableArrows = true;   // Enable Arrows
input color  ArrowUP = clrBlue;     // Arrow UP color
input color  ArrowDOWN = clrMagenta; // Arrow DOWN color

//--- Indicator buffers
double mainBuffer[];
double positiveBuffer[];
double negativeBuffer[];
double rawBuffer[];      // Internal calculation buffer
double signalBuffer[];   // Signal tracking buffer
double arrowBuffer[];    // Arrow buffer

//--- Global variables
string indicatorName = "XB4 MT5";
datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set indicator buffers
   SetIndexBuffer(0, mainBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, positiveBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, negativeBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, rawBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, signalBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, arrowBuffer, INDICATOR_CALCULATIONS);
   
   //--- Set indicator properties
   IndicatorSetString(INDICATOR_SHORTNAME, indicatorName + " (" + IntegerToString(period) + ")");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits + 1);
   
   //--- Set arrays as series
   ArraySetAsSeries(mainBuffer, true);
   ArraySetAsSeries(positiveBuffer, true);
   ArraySetAsSeries(negativeBuffer, true);
   ArraySetAsSeries(rawBuffer, true);
   ArraySetAsSeries(signalBuffer, true);
   ArraySetAsSeries(arrowBuffer, true);
   
   //--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   //--- Initialize buffers
   ArrayInitialize(mainBuffer, EMPTY_VALUE);
   ArrayInitialize(positiveBuffer, EMPTY_VALUE);
   ArrayInitialize(negativeBuffer, EMPTY_VALUE);
   
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
   if(rates_total < period + offset)
      return(0);
      
   //--- Set arrays as series
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(time, true);
   
   //--- Calculate starting position
   int start = prev_calculated;
   if(start == 0)
      start = period + offset;
      
   //--- First calculation pass - raw oscillator values
   double prevSmooth = 0;
   double prevRaw = 0;
   
   for(int i = rates_total - 1 - offset; i >= 0; i--)
   {
      int pos = rates_total - 1 - i; // Convert to series index
      
      //--- Find highest high and lowest low in period
      double highestHigh = high[ArrayMaximum(high, pos, period)];
      double lowestLow = low[ArrayMinimum(low, pos, period)];
      
      //--- Calculate median price
      double medianPrice = (high[pos] + low[pos]) / 2.0;
      
      //--- Calculate smoothed oscillator value
      double currentSmooth = 0.66 * ((medianPrice - lowestLow) / (highestHigh - lowestLow) - 0.5) + 0.67 * prevSmooth;
      currentSmooth = MathMax(MathMin(currentSmooth, 0.999), -0.999);
      
      //--- Calculate Fisher Transform
      rawBuffer[pos] = MathLog((currentSmooth + 1.0) / (1.0 - currentSmooth)) / 2.0 + prevRaw / 2.0;
      
      //--- Store for next iteration
      prevSmooth = currentSmooth;
      prevRaw = rawBuffer[pos];
   }
   
   //--- Second pass - determine trend and fill display buffers
   bool isUpTrend = true;
   
   for(int i = rates_total - 2 - offset; i >= 0; i--)
   {
      int pos = rates_total - 1 - i; // Convert to series index
      
      double currentValue = rawBuffer[pos];
      double prevValue = (pos + 1 < rates_total) ? rawBuffer[pos + 1] : 0;
      
      //--- Determine trend direction
      if((currentValue < 0.0 && prevValue > 0.0) || currentValue < 0.0)
         isUpTrend = false;
      if((currentValue > 0.0 && prevValue < 0.0) || currentValue > 0.0)
         isUpTrend = true;
         
      //--- Fill appropriate buffers
      if(!isUpTrend)
      {
         negativeBuffer[pos] = currentValue;
         positiveBuffer[pos] = EMPTY_VALUE;
         signalBuffer[pos] = -1; // SHORT signal
      }
      else
      {
         positiveBuffer[pos] = currentValue;
         negativeBuffer[pos] = EMPTY_VALUE;
         signalBuffer[pos] = 1; // LONG signal
      }
      
      mainBuffer[pos] = currentValue;
   }
   
   //--- Check for new signals on new bar
   CheckNewSignals(time);
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Check for new signals and generate alerts/arrows               |
//+------------------------------------------------------------------+
void CheckNewSignals(const datetime &time[])
{
   if(!EnableAlerts && !EnableArrows)
      return;
      
   datetime currentBarTime = time[0];
   if(currentBarTime == lastBarTime)
      return;
      
   lastBarTime = currentBarTime;
   
   //--- Check for signal changes
   if(ArraySize(rawBuffer) < 4)
      return;
      
   double current1 = rawBuffer[1];
   double current3 = rawBuffer[3];
   
   //--- BUY signal: was negative, now positive
   if(current3 < 0.0 && current1 > 0.0)
   {
      if(EnableAlerts)
         Alert(_Symbol + " xb4d BUY signal");
         
      if(EnableArrows)
      {
         string objName = "xb4d_Buy_" + TimeToString(currentBarTime);
         double arrowPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         ObjectCreate(0, objName, OBJ_ARROW, 0, currentBarTime, arrowPrice);
         ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 228);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, ArrowUP);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
      }
   }
   
   //--- SELL signal: was positive, now negative  
   if(current3 > 0.0 && current1 < 0.0)
   {
      if(EnableAlerts)
         Alert(_Symbol + " xb4d SELL signal");
         
      if(EnableArrows)
      {
         string objName = "xb4d_Sell_" + TimeToString(currentBarTime);
         double arrowPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         ObjectCreate(0, objName, OBJ_ARROW, 0, currentBarTime, arrowPrice);
         ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 230);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, ArrowDOWN);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
      }
   }
}

//+------------------------------------------------------------------+
//| Get current signal for EA usage                                 |
//+------------------------------------------------------------------+
int GetCurrentSignal(int shift = 0)
{
   if(shift >= ArraySize(signalBuffer))
      return(0);
      
   return((int)signalBuffer[shift]);
}

//+------------------------------------------------------------------+
//| Get oscillator value for EA usage                              |
//+------------------------------------------------------------------+
double GetOscillatorValue(int shift = 0)
{
   if(shift >= ArraySize(rawBuffer))
      return(0);
      
   return(rawBuffer[shift]);
}

//+------------------------------------------------------------------+
//| Check if signal changed (new signal)                           |
//+------------------------------------------------------------------+
bool IsNewSignal(int shift = 0)
{
   if(shift + 1 >= ArraySize(signalBuffer))
      return(false);
      
   return(signalBuffer[shift] != signalBuffer[shift + 1] && signalBuffer[shift] != 0);
}

//+------------------------------------------------------------------+
//| Get signal strength (distance from zero line)                  |
//+------------------------------------------------------------------+
double GetSignalStrength(int shift = 0)
{
   if(shift >= ArraySize(rawBuffer))
      return(0);
      
   return(MathAbs(rawBuffer[shift]));
}
