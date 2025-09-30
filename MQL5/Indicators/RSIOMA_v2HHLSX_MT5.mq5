//+------------------------------------------------------------------+
//|                                           RSIOMA_v2HHLSX_MT5.mq5 |
//|                              Converted from MT4 by GitHub Copilot |
//|                                 RSI with Moving Average MT5      |
//+------------------------------------------------------------------+

#property copyright "RSIOMA v2 MT5"
#property version   "1.03"  // Atualizado para correções: escala fixa 0-100, níveis como indicator levels (não buffers), otimização de performance
#property description "RSI with Moving Average - High/Low levels with optional display and fixed scale"

#property indicator_separate_window
#property indicator_buffers 2  // Reduzido para apenas RSI e MA, níveis movidos para indicator levels
#property indicator_plots   2

#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_width1  2
#property indicator_label1  "RSI"

#property indicator_type2   DRAW_LINE
#property indicator_color2  clrBlue
#property indicator_width2  1
#property indicator_label2  "RSI MA"

//--- Input parameters
input int RSI_Period = 14;           // RSI Period
input int MA_Period = 9;             // Moving Average Period
input ENUM_MA_METHOD MA_Method = MODE_SMA; // MA Method
input double HighLevel = 70.0;       // High Level
input double LowLevel = 30.0;        // Low Level
input bool ShowLevels = true;        // Show high/low levels

//--- Indicator buffers
double rsiBuffer[];
double rsiMaBuffer[];

//--- Handles
int rsi_handle;

//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set indicator buffers
   SetIndexBuffer(0, rsiBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, rsiMaBuffer, INDICATOR_DATA);
   
   //--- Inicialização robusta de arrays para evitar erros em backtesting
   ArrayInitialize(rsiBuffer, EMPTY_VALUE);
   ArrayInitialize(rsiMaBuffer, EMPTY_VALUE);
   
   //--- Set arrays as series
   if(!ArraySetAsSeries(rsiBuffer, true) ||
      !ArraySetAsSeries(rsiMaBuffer, true))
   {
      Print("Error: Failed to set arrays as series");
      return(INIT_FAILED);
   }
   
   rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   if(rsi_handle == INVALID_HANDLE)
   {
      Print("Error: Failed to create RSI handle");
      return(INIT_FAILED);
   }
   
   IndicatorSetString(INDICATOR_SHORTNAME, "RSIOMA v2 (" + 
                     IntegerToString(RSI_Period) + "," + IntegerToString(MA_Period) + ")");
   
   //--- Escala fixa para RSI (0-100), independente dos dados
   IndicatorSetDouble(INDICATOR_MINIMUM, 0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 100);
   
   //--- Configurar níveis como indicator levels (melhor performance, visibilidade garantida)
   if(ShowLevels)
   {
      IndicatorSetInteger(INDICATOR_LEVELS, 2);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, LowLevel);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, HighLevel);
      IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrGray);
      IndicatorSetInteger(INDICATOR_LEVELCOLOR, 1, clrGray);
      IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, STYLE_DOT);
      IndicatorSetInteger(INDICATOR_LEVELSTYLE, 1, STYLE_DOT);
   }
   else
   {
      IndicatorSetInteger(INDICATOR_LEVELS, 0);
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(rsi_handle != INVALID_HANDLE)
      IndicatorRelease(rsi_handle);
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
   if(rates_total < RSI_Period + MA_Period)
      return(0);
   
   double rsi_values[];
   ArraySetAsSeries(rsi_values, true);
   ArrayResize(rsi_values, rates_total);
   
   if(CopyBuffer(rsi_handle, 0, 0, rates_total, rsi_values) <= 0)
   {
      Print("Error: Failed to copy RSI buffer");
      return(0);
   }
   
   int start = (prev_calculated == 0) ? RSI_Period + MA_Period - 1 : prev_calculated - 1;
   
   for(int i = start; i < rates_total; i++)
   {
      int pos = rates_total - 1 - i;
      
      if(pos + MA_Period - 1 >= ArraySize(rsi_values))
         continue;
      
      rsiBuffer[pos] = rsi_values[pos];
      
      // Calculate RSI Moving Average based on MA_Method
      rsiMaBuffer[pos] = CalculateMA(pos, MA_Period, MA_Method, rsi_values);
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Custom MA calculation on array (emulates iMAOnArray, otimizado para baixa latência) |
//+------------------------------------------------------------------+
double CalculateMA(int pos, int period, ENUM_MA_METHOD method, const double &array[])
{
   double sum = 0.0;
   int count = 0;
   
   switch(method)
   {
      case MODE_SMA:
         for(int j = 0; j < period && (pos + j) < ArraySize(array); j++)
         {
            sum += array[pos + j];
            count++;
         }
         return (count > 0) ? sum / count : array[pos];
         
      case MODE_EMA:
      {
         double alpha = 2.0 / (period + 1);
         double ema = array[pos + period - 1];
         for(int j = period - 2; j >= 0; j--)
         {
            if(pos + j >= ArraySize(array)) continue;
            ema = alpha * array[pos + j] + (1 - alpha) * ema;
         }
         return ema;
      }
      
      case MODE_SMMA:
      {
         double smma = array[pos + period - 1];
         for(int j = period - 2; j >= 0; j--)
         {
            if(pos + j >= ArraySize(array)) continue;
            smma = (smma * (period - 1) + array[pos + j]) / period;
         }
         return smma;
      }
      
      case MODE_LWMA:
      {
         double weighted_sum = 0.0;
         double weight_total = 0.0;
         for(int j = 0; j < period && (pos + j) < ArraySize(array); j++)
         {
            double weight = period - j;
            weighted_sum += array[pos + j] * weight;
            weight_total += weight;
         }
         return (weight_total > 0) ? weighted_sum / weight_total : array[pos];
      }
      
      default:
         Print("Warning: Unsupported MA method, falling back to SMA");
         for(int j = 0; j < period && (pos + j) < ArraySize(array); j++)
         {
            sum += array[pos + j];
            count++;
         }
         return (count > 0) ? sum / count : array[pos];
   }
}

//+------------------------------------------------------------------+
double GetRSI(int shift = 0)
{
   return (shift < ArraySize(rsiBuffer)) ? rsiBuffer[shift] : EMPTY_VALUE;
}

//+------------------------------------------------------------------+
double GetRSIMA(int shift = 0)
{
   return (shift < ArraySize(rsiMaBuffer)) ? rsiMaBuffer[shift] : EMPTY_VALUE;
}

//+------------------------------------------------------------------+
bool IsRSIOverbought(int shift = 0)
{
   double rsi = GetRSI(shift);
   return (rsi != EMPTY_VALUE && rsi > HighLevel);
}

//+------------------------------------------------------------------+
bool IsRSIOversold(int shift = 0)
{
   double rsi = GetRSI(shift);
   return (rsi != EMPTY_VALUE && rsi < LowLevel);
}

//+------------------------------------------------------------------+
bool IsRSICrossUp(int shift = 0)
{
   if(shift + 1 >= ArraySize(rsiBuffer) || shift + 1 >= ArraySize(rsiMaBuffer))
      return false;
      
   return (rsiBuffer[shift] > rsiMaBuffer[shift] && 
           rsiBuffer[shift + 1] <= rsiMaBuffer[shift + 1]);
}

//+------------------------------------------------------------------+
bool IsRSICrossDown(int shift = 0)
{
   if(shift + 1 >= ArraySize(rsiBuffer) || shift + 1 >= ArraySize(rsiMaBuffer))
      return false;
      
   return (rsiBuffer[shift] < rsiMaBuffer[shift] && 
           rsiBuffer[shift + 1] >= rsiMaBuffer[shift + 1]);
}
//+------------------------------------------------------------------+