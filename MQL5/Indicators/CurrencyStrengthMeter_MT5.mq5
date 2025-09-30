//+------------------------------------------------------------------+
//|                                    CurrencyStrengthMeter_MT5.mq5 |
//|                              Converted from MT4 by GitHub Copilot |
//|                                     Currency Strength Meter MT5  |
//+------------------------------------------------------------------+

#property copyright "Currency Strength Meter MT5"
#property version   "1.00"
#property description "Multi-currency strength indicator - Auto detection"

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   2

#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLime
#property indicator_width1  2
#property indicator_label1  "Base Currency Strength"

#property indicator_type2   DRAW_LINE  
#property indicator_color2  clrRed
#property indicator_width2  2
#property indicator_label2  "Quote Currency Strength"

//--- Input parameters
input int CalculationPeriod = 24;     // Period for strength calculation
input int SmoothingPeriod = 5;        // Smoothing period
input bool ShowInPercent = true;      // Show in percentage

//--- Indicator buffers
double baseCurrencyBuffer[];
double quoteCurrencyBuffer[];
double tempBuffer1[];
double tempBuffer2[];

//--- Global variables
string baseCurrency = "";
string quoteCurrency = "";
string symbolName = "";

//+------------------------------------------------------------------+
int OnInit()
{
   //--- Detect currencies automatically from current symbol
   symbolName = _Symbol;
   
   if(!DetectCurrencies())
   {
      Print("Error: Cannot detect currencies from symbol: ", symbolName);
      return(INIT_FAILED);
   }
   
   Print("Detected currencies: ", baseCurrency, " / ", quoteCurrency);
   
   //--- Set indicator buffers (sem checagem de retorno, pois void em MQL5)
   SetIndexBuffer(0, baseCurrencyBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, quoteCurrencyBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, tempBuffer1, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, tempBuffer2, INDICATOR_CALCULATIONS);
   
   //--- Inicialização robusta de arrays para evitar erros em backtesting
   ArrayInitialize(baseCurrencyBuffer, 0);
   ArrayInitialize(quoteCurrencyBuffer, 0);
   ArrayInitialize(tempBuffer1, 0);
   ArrayInitialize(tempBuffer2, 0);
   
   //--- Set arrays as series
   if(!ArraySetAsSeries(baseCurrencyBuffer, true) ||
      !ArraySetAsSeries(quoteCurrencyBuffer, true) ||
      !ArraySetAsSeries(tempBuffer1, true) ||
      !ArraySetAsSeries(tempBuffer2, true))
   {
      Print("Error: Failed to set arrays as series");
      return(INIT_FAILED);
   }
   
   //--- Update plot labels with detected currencies
   PlotIndexSetString(0, PLOT_LABEL, baseCurrency + " Strength");
   PlotIndexSetString(1, PLOT_LABEL, quoteCurrency + " Strength");
   
   //--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "Currency Strength: " + baseCurrency + " vs " + quoteCurrency);
   
   //--- Set scale and zero line for visibility
   if(ShowInPercent)
   {
      IndicatorSetDouble(INDICATOR_MINIMUM, -100);
      IndicatorSetDouble(INDICATOR_MAXIMUM, 100);
      IndicatorSetInteger(INDICATOR_LEVELS, 1);
      IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0);
      IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrGray);
      IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, STYLE_DOT);
   }
   
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
bool DetectCurrencies()
{
   //--- Get symbol name and detect currency pattern
   string symbol = _Symbol;
   int symbolLength = StringLen(symbol);
   
   //--- Standard 6-character forex pairs (EURUSD, GBPJPY, etc.) - genérico para XAUUSD também
   if(symbolLength >= 6)
   {
      baseCurrency = StringSubstr(symbol, 0, 3);
      quoteCurrency = StringSubstr(symbol, 3, 3);
      
      //--- Validate currencies (must be alphabetic)
      if(IsValidCurrency(baseCurrency) && IsValidCurrency(quoteCurrency))
         return true;
   }
   
   //--- Try to detect from symbol properties (fallback genérico)
   string baseCurrencyFromMarket = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
   string quoteCurrencyFromMarket = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   
   if(StringLen(baseCurrencyFromMarket) == 3 && StringLen(quoteCurrencyFromMarket) == 3)
   {
      baseCurrency = baseCurrencyFromMarket;
      quoteCurrency = quoteCurrencyFromMarket;
      return true;
   }
   
   //--- Default fallback (sem hardcode)
   baseCurrency = "BASE";
   quoteCurrency = "QUOTE";
   return true;
}
//+------------------------------------------------------------------+
bool IsValidCurrency(string currency)
{
   //--- Check if currency code contains only letters
   for(int i = 0; i < 3; i++)
   {
      ushort ch = StringGetCharacter(currency, i);
      if(ch < 'A' || ch > 'Z')
         return false;
   }
   return true;
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
   if(rates_total < CalculationPeriod + SmoothingPeriod)
      return(0);
   
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   int start = (prev_calculated == 0) ? CalculationPeriod + SmoothingPeriod : prev_calculated - 1;
   
   for(int i = start; i < rates_total; i++)
   {
      int pos = rates_total - 1 - i;
      
      double baseStrength = 0;
      double quoteStrength = 0;
      
      CalculateCurrencyStrengths(pos, CalculationPeriod, close, baseStrength, quoteStrength);
      
      if(SmoothingPeriod > 1)
      {
         baseStrength = ApplySmoothing(baseStrength, pos, SmoothingPeriod, tempBuffer1);
         quoteStrength = ApplySmoothing(quoteStrength, pos, SmoothingPeriod, tempBuffer2);
      }
      
      baseCurrencyBuffer[pos] = baseStrength;
      quoteCurrencyBuffer[pos] = quoteStrength;
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
void CalculateCurrencyStrengths(int pos, int period, const double &close[], double &baseStrength, double &quoteStrength)
{
   if(pos + period >= ArraySize(close))
   {
      baseStrength = 0;
      quoteStrength = 0;
      return;
   }
   
   //--- Get current and past prices with zero check
   double currentPrice = close[pos];
   double pastPrice = close[pos + period];
   
   if(pastPrice == 0 || currentPrice == 0)
   {
      baseStrength = 0;
      quoteStrength = 0;
      return;
   }
   
   //--- Calculate multiple timeframe momentum
   double shortTerm = 0, mediumTerm = 0, longTerm = 0;
   
   // Short term (5 bars)
   if(pos + 5 < ArraySize(close))
      shortTerm = (currentPrice - close[pos + 5]) / close[pos + 5];
   
   // Medium term (period/2)
   if(pos + period/2 < ArraySize(close))
      mediumTerm = (currentPrice - close[pos + period/2]) / close[pos + period/2];
   
   // Long term (full period)
   longTerm = (currentPrice - pastPrice) / pastPrice;
   
   //--- Calculate RSI momentum
   double rsi = CalculateRSI(pos, 14, close);
   double rsiMomentum = (rsi - 50) / 50; // Convert to -1 to +1
   
   //--- Calculate price position in recent range (used minimally now)
   double pricePosition = CalculatePricePosition(pos, period, close);
   
   //--- Volatility calculation early for adjustment
   double volatility = CalculateVolatility(pos, 20, close);
   
   //--- Base signal with weights
   double baseSignal = (shortTerm * 0.2) + (mediumTerm * 0.2) + (longTerm * 0.5) + (rsiMomentum * 0.1);
   
   //--- Strict inverse for quote: remove pricePosition influence, add minor for variation
   double quoteSignal = -baseSignal;
   
   //--- Amplify signals
   baseStrength = baseSignal * 500;  // Aumentado para visibilidade
   quoteStrength = quoteSignal * 500;
   
   //--- Volatility adjustment with higher factor for commodities/metals (genérico agora)
   double volFactor = (volatility > 0.001) ? (1 + volatility * 200) : 1.0;
   baseStrength *= volFactor;
   quoteStrength *= volFactor;
   
   //--- Final bounds with normalization
   baseStrength = MathMax(MathMin(baseStrength, 100), -100);
   quoteStrength = MathMax(MathMin(quoteStrength, 100), -100);
}
//+------------------------------------------------------------------+
double CalculateRSI(int pos, int period, const double &close[])
{
   if(pos + period >= ArraySize(close))
      return 50;
   
   double gains = 0, losses = 0;
   int count = 0;
   
   for(int i = 1; i < period && (pos + i + 1) < ArraySize(close); i++)
   {
      double change = close[pos + i] - close[pos + i + 1];
      
      if(change > 0)
         gains += change;
      else
         losses += MathAbs(change);
      
      count++;
   }
   
   if(count == 0 || losses == 0)
      return 50;
   
   double rs = gains / losses;
   return 100 - (100 / (1 + rs));
}
//+------------------------------------------------------------------+
double CalculatePricePosition(int pos, int period, const double &close[])
{
   if(pos + period >= ArraySize(close))
      return 0;
   
   double highest = close[pos];
   double lowest = close[pos];
   
   // Find highest and lowest in period
   for(int i = 0; i < period && (pos + i) < ArraySize(close); i++)
   {
      if(close[pos + i] > highest) highest = close[pos + i];
      if(close[pos + i] < lowest) lowest = close[pos + i];
   }
   
   if(highest == lowest) return 0;
   
   // Return position in range (-1 to +1)
   return ((close[pos] - lowest) / (highest - lowest)) * 2 - 1;
}
//+------------------------------------------------------------------+
double CalculateVolatility(int pos, int period, const double &close[])
{
   if(pos + period >= ArraySize(close))
      return 0.001;
   
   double sum = 0;
   int count = 0;
   
   for(int i = 1; i < period && (pos + i + 1) < ArraySize(close); i++)
   {
      double change = MathAbs((close[pos + i] - close[pos + i + 1]) / close[pos + i + 1]);
      sum += change;
      count++;
   }
   
   return (count > 0) ? sum / count : 0.001;
}
//+------------------------------------------------------------------+
double ApplySmoothing(double currentValue, int pos, int smoothPeriod, double &smoothBuffer[])
{
   smoothBuffer[pos] = currentValue;
   
   double alpha = 2.0 / (smoothPeriod + 1);
   
   if(pos + 1 < ArraySize(smoothBuffer) && smoothBuffer[pos + 1] != 0)
   {
      return alpha * currentValue + (1 - alpha) * smoothBuffer[pos + 1];
   }
   
   return currentValue;
}

//+------------------------------------------------------------------+
double GetBaseCurrencyStrength(int shift = 0)
{
   return (shift < ArraySize(baseCurrencyBuffer)) ? baseCurrencyBuffer[shift] : 0;
}

//+------------------------------------------------------------------+
double GetQuoteCurrencyStrength(int shift = 0)
{
   return (shift < ArraySize(quoteCurrencyBuffer)) ? quoteCurrencyBuffer[shift] : 0;
}

//+------------------------------------------------------------------+
string GetBaseCurrency()
{
   return baseCurrency;
}

//+------------------------------------------------------------------+
string GetQuoteCurrency()
{
   return quoteCurrency;
}

//+------------------------------------------------------------------+
bool IsBaseCurrencyStrong(int shift = 0)
{
   return (GetBaseCurrencyStrength(shift) > 0);
}

//+------------------------------------------------------------------+
bool IsQuoteCurrencyStrong(int shift = 0)
{
   return (GetQuoteCurrencyStrength(shift) > 0);
}
//+------------------------------------------------------------------+