//+------------------------------------------------------------------+
//|                                            BuyellSignal_MT5.mq5 |
//|                              Converted from MT4 by GitHub Copilot |
//|                                              MT5 Compatible Version |
//+------------------------------------------------------------------+

#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_width1  1
#property indicator_label1  "Fast EMA"

#property indicator_type2   DRAW_LINE
#property indicator_color2  clrYellow
#property indicator_width2  1
#property indicator_label2  "Slow EMA"

#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrAqua
#property indicator_width3  2
#property indicator_label3  "Buy Signal"

#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_width4  2
#property indicator_label4  "Sell Signal"

//--- Input parameters
input int FastEMA = 13;        // Fast EMA Period
input int SlowEMA = 21;        // Slow EMA Period
input int RSIPeriod = 9;       // RSI Period
input bool ShowArrows = true;  // Show Buy/Sell Arrows
input bool Alerts = false;     // Enable Alerts

//--- Indicator buffers
double fastEmaBuffer[];
double slowEmaBuffer[];
double buySignalBuffer[];
double sellSignalBuffer[];

//--- Indicator handles
int fastEma_handle;
int slowEma_handle;
int rsi_handle;

//--- Global variables
int currentSignal = 0;
int previousSignal = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set indicator buffers
   SetIndexBuffer(0, fastEmaBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, slowEmaBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, buySignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, sellSignalBuffer, INDICATOR_DATA);
   
   //--- Set arrow codes
   PlotIndexSetInteger(2, PLOT_ARROW, 217);
   PlotIndexSetInteger(3, PLOT_ARROW, 218);
   
   //--- Set empty values
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   //--- Create indicator handles
   fastEma_handle = iMA(_Symbol, PERIOD_CURRENT, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   slowEma_handle = iMA(_Symbol, PERIOD_CURRENT, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
   
   if(fastEma_handle == INVALID_HANDLE || slowEma_handle == INVALID_HANDLE || rsi_handle == INVALID_HANDLE)
   {
      Print("Failed to create indicator handles");
      return(INIT_FAILED);
   }
   
   //--- Set indicator properties
   IndicatorSetString(INDICATOR_SHORTNAME, "BuySell Signal MT5 (" + 
                     IntegerToString(FastEMA) + "," + 
                     IntegerToString(SlowEMA) + "," + 
                     IntegerToString(RSIPeriod) + ")");
   
   //--- Set arrays as series
   ArraySetAsSeries(fastEmaBuffer, true);
   ArraySetAsSeries(slowEmaBuffer, true);
   ArraySetAsSeries(buySignalBuffer, true);
   ArraySetAsSeries(sellSignalBuffer, true);
   
   //--- Hide arrows if disabled
   if(!ShowArrows)
   {
      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_NONE);
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   if(fastEma_handle != INVALID_HANDLE)
      IndicatorRelease(fastEma_handle);
   if(slowEma_handle != INVALID_HANDLE)
      IndicatorRelease(slowEma_handle);
   if(rsi_handle != INVALID_HANDLE)
      IndicatorRelease(rsi_handle);
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
   if(rates_total < MathMax(FastEMA, MathMax(SlowEMA, RSIPeriod)))
      return(0);
      
   //--- Set arrays as series
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   //--- Get indicator values
   double fastEma_values[];
   double slowEma_values[];
   double rsi_values[];
   
   ArraySetAsSeries(fastEma_values, true);
   ArraySetAsSeries(slowEma_values, true);
   ArraySetAsSeries(rsi_values, true);
   
   int copy_bars = rates_total - prev_calculated + 10;
   if(prev_calculated == 0)
      copy_bars = rates_total;
   
   if(CopyBuffer(fastEma_handle, 0, 0, copy_bars, fastEma_values) <= 0)
      return(0);
   if(CopyBuffer(slowEma_handle, 0, 0, copy_bars, slowEma_values) <= 0)
      return(0);
   if(CopyBuffer(rsi_handle, 0, 0, copy_bars, rsi_values) <= 0)
      return(0);
   
   //--- Calculate starting position
   int start = prev_calculated;
   if(start == 0)
      start = 1;
   
   //--- Main calculation loop
   for(int i = start; i < rates_total; i++)
   {
      int pos = rates_total - 1 - i; // Convert to series index
      
      //--- Copy EMA values to buffers
      fastEmaBuffer[pos] = fastEma_values[pos];
      slowEmaBuffer[pos] = slowEma_values[pos];
      
      //--- Initialize signal buffers
      buySignalBuffer[pos] = EMPTY_VALUE;
      sellSignalBuffer[pos] = EMPTY_VALUE;
      
      //--- Get current values
      double fastEma_current = fastEma_values[pos];
      double slowEma_current = slowEma_values[pos];
      double rsi_current = rsi_values[pos];
      
      //--- Calculate pip difference
      double pipDiff = fastEma_current - slowEma_current;
      
      //--- Determine current signal
      currentSignal = 0;
      if(pipDiff > 0.0 && rsi_current > 50.0)
         currentSignal = 1; // Buy signal
      else if(pipDiff < 0.0 && rsi_current < 50.0)
         currentSignal = 2; // Sell signal
      
      //--- Check for signal change and generate arrows
      if(pos < rates_total - 1)
      {
         if(currentSignal == 1 && previousSignal == 2)
         {
            buySignalBuffer[pos] = low[pos] - 5.0 * _Point;
            
            //--- Generate alert
            if(Alerts && pos == 0)
            {
               Alert("BUY SIGNAL at ", _Symbol, " - Price: ", DoubleToString(close[pos], _Digits));
            }
         }
         else if(currentSignal == 2 && previousSignal == 1)
         {
            sellSignalBuffer[pos] = high[pos] + 5.0 * _Point;
            
            //--- Generate alert
            if(Alerts && pos == 0)
            {
               Alert("SELL SIGNAL at ", _Symbol, " - Price: ", DoubleToString(close[pos], _Digits));
            }
         }
      }
      
      previousSignal = currentSignal;
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Get current signal for EA usage                                 |
//+------------------------------------------------------------------+
int GetCurrentSignal(int shift = 0)
{
   if(shift >= ArraySize(fastEmaBuffer) || shift >= ArraySize(slowEmaBuffer))
      return(0);
      
   double fastEma = fastEmaBuffer[shift];
   double slowEma = slowEmaBuffer[shift];
   
   // Get RSI value
   double rsi_values[];
   ArraySetAsSeries(rsi_values, true);
   if(CopyBuffer(rsi_handle, 0, shift, 1, rsi_values) <= 0)
      return(0);
   
   double pipDiff = fastEma - slowEma;
   double rsi_current = rsi_values[0];
   
   if(pipDiff > 0.0 && rsi_current > 50.0)
      return(1); // Buy signal
   else if(pipDiff < 0.0 && rsi_current < 50.0)
      return(-1); // Sell signal
   else
      return(0); // No signal
}

//+------------------------------------------------------------------+
//| Check for new signal (signal change)                            |
//+------------------------------------------------------------------+
bool IsNewSignal(int shift = 0)
{
   if(shift + 1 >= ArraySize(fastEmaBuffer))
      return(false);
      
   int currentSig = GetCurrentSignal(shift);
   int previousSig = GetCurrentSignal(shift + 1);
   
   return(currentSig != 0 && currentSig != previousSig);
}

//+------------------------------------------------------------------+
//| Get EMA difference for EA usage                                 |
//+------------------------------------------------------------------+
double GetEMADifference(int shift = 0)
{
   if(shift >= ArraySize(fastEmaBuffer) || shift >= ArraySize(slowEmaBuffer))
      return(0);
      
   return(fastEmaBuffer[shift] - slowEmaBuffer[shift]);
}

//+------------------------------------------------------------------+
//| Get RSI value for EA usage                                      |
//+------------------------------------------------------------------+
double GetRSIValue(int shift = 0)
{
   double rsi_values[];
   ArraySetAsSeries(rsi_values, true);
   
   if(CopyBuffer(rsi_handle, 0, shift, 1, rsi_values) <= 0)
      return(0);
      
   return(rsi_values[0]);
}
