//+------------------------------------------------------------------+
//|                                  HighGainTradingSystem_EA.mq5   |
//|                             High Gain Trading System EA v1.0    |
//|                   Advanced Scalping EA with Multiple Indicators |
//+------------------------------------------------------------------+

#property copyright "High Gain Trading System EA"
#property version   "1.00"
#property description "Multi-indicator scalping system with advanced filters"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Trading objects
CTrade         m_trade;
CPositionInfo  m_position;
COrderInfo     m_order;

//--- Input Parameters
input group "=== EA SETTINGS ==="
input int      MagicNumber        = 123456;         // Magic Number
input double   LotSize            = 0.01;           // Lot Size
input bool     UseAutoLot         = false;          // Use Auto Lot Calculation
input double   RiskPercent        = 2.0;            // Risk Percent for Auto Lot
input int      Slippage           = 3;              // Slippage in Points

input group "=== TRADE MANAGEMENT ==="
input bool     UseStopLoss        = true;           // Use Stop Loss
input int      StopLossPips       = 20;             // Stop Loss in Pips (if not using Trend Magic)
input bool     UseTakeProfit      = true;           // Use Take Profit
input int      TakeProfitPips     = 40;             // Take Profit in Pips
input bool     UseTrailingStop    = true;           // Use Trailing Stop
input int      TrailingStopPips   = 15;             // Trailing Stop in Pips
input int      TrailingStepPips   = 5;              // Trailing Step in Pips

input group "=== INDICATOR SETTINGS ==="
input int      TrendMagic_CCI     = 50;             // Trend Magic CCI Period
input int      TrendMagic_ATR     = 5;              // Trend Magic ATR Period
input double   TrendMagic_Mult    = 1.0;            // Trend Magic ATR Multiplier

input double   HiGann_Phase       = 0.0;            // Hi Gann Phase
input int      HiGann_CalcMode    = 1;              // Hi Gann Calculation Mode
input int      HiGann_PriceType   = 4;              // Hi Gann Price Type
input int      HiGann_Smooth      = 5;              // Hi Gann Smooth Period

input int      SolarWinds_Period  = 35;             // Solar Winds Period
input int      SolarWinds_Smooth  = 10;             // Solar Winds Smooth

input int      XB4_Period         = 27;             // XB4 Period

input int      RSIOMA_RSI_Period  = 14;             // RSIOMA RSI Period
input int      RSIOMA_MA_Period   = 9;              // RSIOMA MA Period
input double   RSIOMA_HighLevel   = 80.0;           // RSIOMA High Level
input double   RSIOMA_LowLevel    = 20.0;           // RSIOMA Low Level

input int      BuySell_FastEMA    = 13;             // Buy-Sell Fast EMA
input int      BuySell_SlowEMA    = 21;             // Buy-Sell Slow EMA
input int      BuySell_RSIPeriod  = 9;              // Buy-Sell RSI Period

input group "=== TIME FILTERS ==="
input bool     UseTimeFilter      = true;           // Use Time Filter
input string   StartTime          = "08:00";        // Start Time (HH:MM)
input string   EndTime            = "18:00";        // End Time (HH:MM)

input group "=== WEEKLY FILTER ==="
input bool     UseWeeklyFilter    = true;           // Use Weekly Filter
input bool     TradeMon           = true;           // Trade on Monday
input bool     TradeTue           = true;           // Trade on Tuesday
input bool     TradeWed           = true;           // Trade on Wednesday
input bool     TradeThu           = true;           // Trade on Thursday
input bool     TradeFri           = true;           // Trade on Friday
input bool     TradeSat           = false;          // Trade on Saturday
input bool     TradeSun           = false;          // Trade on Sunday

input group "=== FILTER SETTINGS ==="
input bool     UseMultiEntryProtection = true;     // Prevent Multiple Entries
input int      MinBarsBetweenTrades    = 5;        // Minimum Bars Between Trades
input bool     UseSignalFiltering      = true;     // Use Advanced Signal Filtering
input int      SignalConfirmBars       = 2;        // Signal Confirmation Bars

//--- Global Variables
int h_TrendMagic, h_HiGann, h_SolarWinds, h_XB4, h_RSIOMA, h_BuySell;
datetime lastTradeTime = 0;
double pointValue;
bool tradingAllowed = true;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Setup trade object
   m_trade.SetExpertMagicNumber(MagicNumber);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(_Symbol);
   m_trade.SetDeviationInPoints(Slippage);
   
   //--- Calculate point value
   pointValue = (_Digits == 5 || _Digits == 3) ? 10 * _Point : _Point;
   
   //--- Initialize indicators
   if(!InitializeIndicators())
   {
      Print("ERROR: Failed to initialize indicators");
      return(INIT_FAILED);
   }
   
   //--- Validate inputs
   if(!ValidateInputs())
   {
      Print("ERROR: Invalid input parameters");
      return(INIT_FAILED);
   }
   
   Print("High Gain Trading System EA initialized successfully");
   Print("Symbol: ", _Symbol, " | Magic Number: ", MagicNumber);
   Print("Lot Size: ", LotSize, " | Auto Lot: ", UseAutoLot ? "Yes" : "No");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   if(h_TrendMagic != INVALID_HANDLE) IndicatorRelease(h_TrendMagic);
   if(h_HiGann != INVALID_HANDLE) IndicatorRelease(h_HiGann);
   if(h_SolarWinds != INVALID_HANDLE) IndicatorRelease(h_SolarWinds);
   if(h_XB4 != INVALID_HANDLE) IndicatorRelease(h_XB4);
   if(h_RSIOMA != INVALID_HANDLE) IndicatorRelease(h_RSIOMA);
   if(h_BuySell != INVALID_HANDLE) IndicatorRelease(h_BuySell);
   
   Print("High Gain Trading System EA deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check if new bar
   static datetime lastBar = 0;
   if(iTime(_Symbol, PERIOD_CURRENT, 0) == lastBar) return;
   lastBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   //--- Check trading conditions
   if(!IsNewBarReady()) return;
   if(!CheckTimeFilters()) return;
   if(!CheckWeeklyFilter()) return;
   
   //--- Update trailing stops
   UpdateTrailingStops();
   
   //--- Check for new signals
   CheckTradingSignals();
}

//+------------------------------------------------------------------+
//| Initialize all indicators                                        |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
   //--- TrendMagic MT5
   h_TrendMagic = iCustom(_Symbol, PERIOD_CURRENT, "Indicators\\TrendMagic_MT5",
                         TrendMagic_CCI, TrendMagic_ATR, TrendMagic_Mult);
   if(h_TrendMagic == INVALID_HANDLE) return false;
   
   //--- Hi Gann Activator
   h_HiGann = iCustom(_Symbol, PERIOD_CURRENT, "Indicators\\HiGannActivator_MT5",
                     HiGann_Phase, HiGann_CalcMode, HiGann_PriceType, HiGann_Smooth,
                     true, 1.0, false);
   if(h_HiGann == INVALID_HANDLE) return false;
   
   //--- Solar Winds Joy
   h_SolarWinds = iCustom(_Symbol, PERIOD_CURRENT, "Indicators\\SolarWindsJoy_MT5",
                         SolarWinds_Period, SolarWinds_Smooth);
   if(h_SolarWinds == INVALID_HANDLE) return false;
   
   //--- XB4
   h_XB4 = iCustom(_Symbol, PERIOD_CURRENT, "Indicators\\xb4d_MT5",
                   XB4_Period, 0, true, true, clrBlue, clrMagenta);
   if(h_XB4 == INVALID_HANDLE) return false;
   
   //--- RSIOMA
   h_RSIOMA = iCustom(_Symbol, PERIOD_CURRENT, "Indicators\\RSIOMA_v2HHLSX_MT5",
                     RSIOMA_RSI_Period, RSIOMA_MA_Period, MODE_SMA,
                     RSIOMA_HighLevel, RSIOMA_LowLevel, true);
   if(h_RSIOMA == INVALID_HANDLE) return false;
   
   //--- Buy-Sell Signal
   h_BuySell = iCustom(_Symbol, PERIOD_CURRENT, "Indicators\\BuyellSignal_MT5",
                      BuySell_FastEMA, BuySell_SlowEMA, BuySell_RSIPeriod, 0, true);
   if(h_BuySell == INVALID_HANDLE) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check trading signals and execute trades                        |
//+------------------------------------------------------------------+
void CheckTradingSignals()
{
   //--- Check for multiple entry protection
   if(UseMultiEntryProtection && HasRecentTrade()) return;
   if(CountPositions() > 0) return; // Only one position at a time
   
   //--- Get indicator signals
   int trendMagicSignal = GetTrendMagicSignal();
   int hiGannSignal = GetHiGannSignal();
   int solarWindsSignal = GetSolarWindsSignal();
   int xb4Signal = GetXB4Signal();
   int rsiomaSignal = GetRSIOMASignal();
   int buySellSignal = GetBuySellSignal();
   
   //--- Check for BUY conditions
   bool buyCondition = (trendMagicSignal == 1) &&    // Trend Magic yellow/bullish
                       (hiGannSignal == 1) &&         // Hi Gann bullish signal
                       (solarWindsSignal == 1) &&     // Solar Winds positive
                       (xb4Signal == 1) &&            // XB4 positive
                       (rsiomaSignal == 1) &&         // RSIOMA bullish crossover near 20
                       (buySellSignal == 1);          // Buy-Sell indicator confirms
   
   //--- Check for SELL conditions
   bool sellCondition = (trendMagicSignal == -1) &&  // Trend Magic blue/bearish
                        (hiGannSignal == -1) &&       // Hi Gann bearish signal
                        (solarWindsSignal == -1) &&   // Solar Winds negative
                        (xb4Signal == -1) &&          // XB4 negative
                        (rsiomaSignal == -1) &&       // RSIOMA bearish crossover near 80
                        (buySellSignal == -1);        // Buy-Sell indicator confirms
   
   //--- Execute trades
   if(buyCondition && ConfirmSignal(1))
   {
      OpenBuyTrade();
   }
   else if(sellCondition && ConfirmSignal(-1))
   {
      OpenSellTrade();
   }
}

//+------------------------------------------------------------------+
//| Open Buy Trade                                                   |
//+------------------------------------------------------------------+
void OpenBuyTrade()
{
   double lot = CalculateLotSize();
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = 0, tp = 0;
   
   //--- Calculate Stop Loss
   if(UseStopLoss)
   {
      double trendMagicLevel = GetTrendMagicLevel();
      if(trendMagicLevel > 0)
         sl = trendMagicLevel - (5 * pointValue); // Below Trend Magic level
      else
         sl = price - (StopLossPips * pointValue);
   }
   
   //--- Calculate Take Profit
   if(UseTakeProfit)
   {
      tp = price + (TakeProfitPips * pointValue);
   }
   
   //--- Execute trade
   if(m_trade.Buy(lot, _Symbol, price, sl, tp, "High Gain BUY"))
   {
      lastTradeTime = TimeCurrent();
      Print("BUY order opened: Price=", price, " SL=", sl, " TP=", tp, " Lot=", lot);
   }
   else
   {
      Print("Failed to open BUY order: ", m_trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Open Sell Trade                                                  |
//+------------------------------------------------------------------+
void OpenSellTrade()
{
   double lot = CalculateLotSize();
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = 0, tp = 0;
   
   //--- Calculate Stop Loss
   if(UseStopLoss)
   {
      double trendMagicLevel = GetTrendMagicLevel();
      if(trendMagicLevel > 0)
         sl = trendMagicLevel + (5 * pointValue); // Above Trend Magic level
      else
         sl = price + (StopLossPips * pointValue);
   }
   
   //--- Calculate Take Profit
   if(UseTakeProfit)
   {
      tp = price - (TakeProfitPips * pointValue);
   }
   
   //--- Execute trade
   if(m_trade.Sell(lot, _Symbol, price, sl, tp, "High Gain SELL"))
   {
      lastTradeTime = TimeCurrent();
      Print("SELL order opened: Price=", price, " SL=", sl, " TP=", tp, " Lot=", lot);
   }
   else
   {
      Print("Failed to open SELL order: ", m_trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Get Trend Magic Signal                                           |
//+------------------------------------------------------------------+
int GetTrendMagicSignal()
{
   double upBuffer[], downBuffer[];
   ArraySetAsSeries(upBuffer, true);
   ArraySetAsSeries(downBuffer, true);
   
   if(CopyBuffer(h_TrendMagic, 0, 0, 3, upBuffer) < 3) return 0;
   if(CopyBuffer(h_TrendMagic, 1, 0, 3, downBuffer) < 3) return 0;
   
   // Check current trend direction
   if(upBuffer[0] != EMPTY_VALUE && downBuffer[0] == EMPTY_VALUE) return 1;   // Bullish
   if(downBuffer[0] != EMPTY_VALUE && upBuffer[0] == EMPTY_VALUE) return -1;  // Bearish
   
   return 0;
}

//+------------------------------------------------------------------+
//| Get Hi Gann Signal                                               |
//+------------------------------------------------------------------+
int GetHiGannSignal()
{
   double buyArrow[], sellArrow[];
   ArraySetAsSeries(buyArrow, true);
   ArraySetAsSeries(sellArrow, true);
   
   if(CopyBuffer(h_HiGann, 3, 0, 3, buyArrow) < 3) return 0;    // Buy arrows
   if(CopyBuffer(h_HiGann, 4, 0, 3, sellArrow) < 3) return 0;   // Sell arrows
   
   // Check for recent arrow signals
   for(int i = 0; i < 3; i++)
   {
      if(buyArrow[i] != EMPTY_VALUE) return 1;   // Buy signal
      if(sellArrow[i] != EMPTY_VALUE) return -1; // Sell signal
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Get Solar Winds Signal                                           |
//+------------------------------------------------------------------+
int GetSolarWindsSignal()
{
   double signalLine[];
   ArraySetAsSeries(signalLine, true);
   
   if(CopyBuffer(h_SolarWinds, 2, 0, 3, signalLine) < 3) return 0;
   
   if(signalLine[0] > 0) return 1;   // Positive
   if(signalLine[0] < 0) return -1;  // Negative
   
   return 0;
}

//+------------------------------------------------------------------+
//| Get XB4 Signal                                                   |
//+------------------------------------------------------------------+
int GetXB4Signal()
{
   double mainBuffer[];
   ArraySetAsSeries(mainBuffer, true);
   
   if(CopyBuffer(h_XB4, 0, 0, 3, mainBuffer) < 3) return 0;
   
   if(mainBuffer[0] > 0) return 1;   // Positive
   if(mainBuffer[0] < 0) return -1;  // Negative
   
   return 0;
}

//+------------------------------------------------------------------+
//| Get RSIOMA Signal                                                |
//+------------------------------------------------------------------+
int GetRSIOMASignal()
{
   double rsiBuffer[], maBuffer[];
   ArraySetAsSeries(rsiBuffer, true);
   ArraySetAsSeries(maBuffer, true);
   
   if(CopyBuffer(h_RSIOMA, 0, 0, 3, rsiBuffer) < 3) return 0;
   if(CopyBuffer(h_RSIOMA, 1, 0, 3, maBuffer) < 3) return 0;
   
   // Check for bullish crossover near oversold level
   if(rsiBuffer[0] > maBuffer[0] && rsiBuffer[1] <= maBuffer[1] && rsiBuffer[0] < 30)
      return 1;
   
   // Check for bearish crossover near overbought level
   if(rsiBuffer[0] < maBuffer[0] && rsiBuffer[1] >= maBuffer[1] && rsiBuffer[0] > 70)
      return -1;
   
   return 0;
}

//+------------------------------------------------------------------+
//| Get Buy-Sell Signal                                              |
//+------------------------------------------------------------------+
int GetBuySellSignal()
{
   double buyArrow[], sellArrow[];
   ArraySetAsSeries(buyArrow, true);
   ArraySetAsSeries(sellArrow, true);
   
   if(CopyBuffer(h_BuySell, 2, 0, 3, buyArrow) < 3) return 0;
   if(CopyBuffer(h_BuySell, 3, 0, 3, sellArrow) < 3) return 0;
   
   // Check for recent signals
   for(int i = 0; i < 2; i++)
   {
      if(buyArrow[i] != EMPTY_VALUE) return 1;
      if(sellArrow[i] != EMPTY_VALUE) return -1;
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Calculate lot size                                               |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double lot = LotSize;
   
   if(UseAutoLot)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = balance * (RiskPercent / 100.0);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double stopLossPoints = StopLossPips * pointValue / _Point;
      
      if(tickValue > 0 && stopLossPoints > 0)
      {
         lot = riskAmount / (stopLossPoints * tickValue);
      }
   }
   
   // Normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = NormalizeDouble(lot / stepLot, 0) * stepLot;
   
   return lot;
}

//+------------------------------------------------------------------+
//| Update trailing stops                                            |
//+------------------------------------------------------------------+
void UpdateTrailingStops()
{
   if(!UseTrailingStop) return;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol() != _Symbol) continue;
      if(m_position.Magic() != MagicNumber) continue;
      
      double currentPrice = (m_position.PositionType() == POSITION_TYPE_BUY) ? 
                           SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                           SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      double newSL = 0;
      bool modifyNeeded = false;
      
      if(m_position.PositionType() == POSITION_TYPE_BUY)
      {
         newSL = currentPrice - (TrailingStopPips * pointValue);
         if(newSL > m_position.StopLoss() + (TrailingStepPips * pointValue))
            modifyNeeded = true;
      }
      else
      {
         newSL = currentPrice + (TrailingStopPips * pointValue);
         if(newSL < m_position.StopLoss() - (TrailingStepPips * pointValue))
            modifyNeeded = true;
      }
      
      if(modifyNeeded)
      {
         m_trade.PositionModify(m_position.Ticket(), newSL, m_position.TakeProfit());
      }
   }
}

//+------------------------------------------------------------------+
//| Check time filters                                               |
//+------------------------------------------------------------------+
bool CheckTimeFilters()
{
   if(!UseTimeFilter) return true;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   int currentTime = dt.hour * 100 + dt.min;
   int startTime = StringToInteger(StringSubstr(StartTime, 0, 2)) * 100 + 
                   StringToInteger(StringSubstr(StartTime, 3, 2));
   int endTime = StringToInteger(StringSubstr(EndTime, 0, 2)) * 100 + 
                 StringToInteger(StringSubstr(EndTime, 3, 2));
   
   if(startTime <= endTime)
      return (currentTime >= startTime && currentTime <= endTime);
   else
      return (currentTime >= startTime || currentTime <= endTime);
}

//+------------------------------------------------------------------+
//| Check weekly filter                                              |
//+------------------------------------------------------------------+
bool CheckWeeklyFilter()
{
   if(!UseWeeklyFilter) return true;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   switch(dt.day_of_week)
   {
      case 1: return TradeMon;
      case 2: return TradeTue;
      case 3: return TradeWed;
      case 4: return TradeThu;
      case 5: return TradeFri;
      case 6: return TradeSat;
      case 0: return TradeSun;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Helper functions                                                 |
//+------------------------------------------------------------------+
bool IsNewBarReady()
{
   return (iBars(_Symbol, PERIOD_CURRENT) > 100);
}

bool HasRecentTrade()
{
   return (TimeCurrent() - lastTradeTime < MinBarsBetweenTrades * PeriodSeconds());
}

int CountPositions()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Symbol() == _Symbol && m_position.Magic() == MagicNumber)
         count++;
   }
   return count;
}

double GetTrendMagicLevel()
{
   double upBuffer[], downBuffer[];
   ArraySetAsSeries(upBuffer, true);
   ArraySetAsSeries(downBuffer, true);
   
   if(CopyBuffer(h_TrendMagic, 0, 0, 1, upBuffer) < 1) return 0;
   if(CopyBuffer(h_TrendMagic, 1, 0, 1, downBuffer) < 1) return 0;
   
   if(upBuffer[0] != EMPTY_VALUE) return upBuffer[0];
   if(downBuffer[0] != EMPTY_VALUE) return downBuffer[0];
   
   return 0;
}

bool ConfirmSignal(int signal)
{
   if(!UseSignalFiltering) return true;
   
   // Additional signal confirmation logic can be added here
   static int lastSignal = 0;
   static int signalCount = 0;
   
   if(signal == lastSignal)
   {
      signalCount++;
   }
   else
   {
      lastSignal = signal;
      signalCount = 1;
   }
   
   return (signalCount >= SignalConfirmBars);
}

bool ValidateInputs()
{
   if(LotSize <= 0) return false;
   if(MagicNumber <= 0) return false;
   if(StopLossPips < 0) return false;
   if(TakeProfitPips < 0) return false;
   
   return true;
}
