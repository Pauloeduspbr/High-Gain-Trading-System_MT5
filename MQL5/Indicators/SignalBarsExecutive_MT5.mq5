//+------------------------------------------------------------------+
//|                                      SignalBarsExecutive_MT5.mq5 |
//|                              Converted from MT4 by GitHub Copilot |
//|                                   Signal Bars Executive MT5      |
//+------------------------------------------------------------------+

#property copyright "Signal Bars Executive MT5"
#property version   "1.00"
#property description "Executive signal bars indicator"

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  3
#property indicator_label1  "Buy Signal"

#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  3
#property indicator_label2  "Sell Signal"

//--- Input parameters
input int SignalPeriod = 21;         // Signal calculation period
input double SignalThreshold = 0.5;  // Signal threshold
input bool ShowAlerts = true;        // Show alerts

//--- Indicator buffers
double buySignalBuffer[];
double sellSignalBuffer[];

//--- Global variables
datetime lastAlertTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, buySignalBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, sellSignalBuffer, INDICATOR_DATA);
   
   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);
   
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   ArraySetAsSeries(buySignalBuffer, true);
   ArraySetAsSeries(sellSignalBuffer, true);
   
   IndicatorSetString(INDICATOR_SHORTNAME, "Signal Bars Executive MT5");
   
   return(INIT_SUCCEEDED);
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
   if(rates_total < SignalPeriod + 10)
      return(0);
   
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   int start = (prev_calculated == 0) ? SignalPeriod : prev_calculated - 1;
   
   for(int i = start; i < rates_total; i++)
   {
      int pos = rates_total - 1 - i;
      
      buySignalBuffer[pos] = EMPTY_VALUE;
      sellSignalBuffer[pos] = EMPTY_VALUE;
      
      // Simplified signal logic - based on price momentum
      double currentPrice = close[pos];
      double previousPrice = (pos + SignalPeriod < rates_total) ? close[pos + SignalPeriod] : close[pos];
      
      double priceChange = (currentPrice - previousPrice) / previousPrice;
      
      if(priceChange > SignalThreshold / 100.0)
      {
         buySignalBuffer[pos] = low[pos] - (high[pos] - low[pos]) * 0.2;
         
         if(ShowAlerts && time[pos] != lastAlertTime)
         {
            Alert(_Symbol + " - BUY Signal at ", TimeToString(time[pos]));
            lastAlertTime = time[pos];
         }
      }
      else if(priceChange < -SignalThreshold / 100.0)
      {
         sellSignalBuffer[pos] = high[pos] + (high[pos] - low[pos]) * 0.2;
         
         if(ShowAlerts && time[pos] != lastAlertTime)
         {
            Alert(_Symbol + " - SELL Signal at ", TimeToString(time[pos]));
            lastAlertTime = time[pos];
         }
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
bool HasBuySignal(int shift = 0)
{
   return (shift < ArraySize(buySignalBuffer) && buySignalBuffer[shift] != EMPTY_VALUE);
}

//+------------------------------------------------------------------+
bool HasSellSignal(int shift = 0)
{
   return (shift < ArraySize(sellSignalBuffer) && sellSignalBuffer[shift] != EMPTY_VALUE);
}
               Alert(_Symbol + " - SELL Signal at ", TimeToString(time[pos]));
               lastAlertTime = time[pos];
            }
         }
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
double CalculateSignalStrength(int pos, int period, const double &h[], const double &l[], const double &c[])
{
   double strength = 0;
   
   for(int i = 0; i < period && (pos + i) < ArraySize(c); i++)
   {
      double range = h[pos + i] - l[pos + i];
      double bodySize = MathAbs(c[pos + i] - c[pos + i + 1]);
      
      if(range > 0)
         strength += bodySize / range;
   }
   
   return strength / period;
}

//+------------------------------------------------------------------+
double CalculateTrend(int pos, int period, const double &c[])
{
   if(pos + period >= ArraySize(c))
      return 0;
   
   double currentAvg = 0;
   double previousAvg = 0;
   
   // Calculate current average
   for(int i = 0; i < period / 2; i++)
   {
      currentAvg += c[pos + i];
   }
   currentAvg /= (period / 2);
   
   // Calculate previous average
   for(int i = period / 2; i < period; i++)
   {
      previousAvg += c[pos + i];
   }
   previousAvg /= (period / 2);
   
   return currentAvg - previousAvg;
}

//+------------------------------------------------------------------+
bool HasBuySignal(int shift = 0)
{
   return (shift < ArraySize(buySignalBuffer) && buySignalBuffer[shift] != EMPTY_VALUE);
}

//+------------------------------------------------------------------+
bool HasSellSignal(int shift = 0)
{
   return (shift < ArraySize(sellSignalBuffer) && sellSignalBuffer[shift] != EMPTY_VALUE);
}

//+------------------------------------------------------------------+
double GetSignalStrength(int shift = 0)
{
   return (shift < ArraySize(signalStrengthBuffer)) ? signalStrengthBuffer[shift] : 0;
}
