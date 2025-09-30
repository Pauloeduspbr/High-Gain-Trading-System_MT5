//+------------------------------------------------------------------+
//|                                         KH_TradeMonitor_v2_MT5.mq5 |
//|                              Converted from MT4 by GitHub Copilot |
//|                                        KH Trade Monitor v2 MT5    |
//+------------------------------------------------------------------+

#property copyright "KH Trade Monitor v2 MT5"
#property version   "2.01"  // Atualizado para correções: fix em SYMBOL_TRADE_MODE, loops de posições, ObjectsTotal/ObjectName e SymbolInfoSessionTrade
#property description "Advanced trade monitoring and information dashboard com tratamento de erros e otimização para baixa latência"

#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- Input parameters
input group "=== DISPLAY SETTINGS ==="
input int    PanelX = 20;              // Panel X Position
input int    PanelY = 50;              // Panel Y Position
input int    FontSize = 9;             // Font Size
input color  TextColor = clrWhite;     // Text Color
input color  BackgroundColor = clrBlack; // Background Color
input bool   ShowSpread = true;        // Show Spread Info
input bool   ShowSwap = true;          // Show Swap Info
input bool   ShowMargin = true;        // Show Margin Info
input bool   ShowProfit = true;        // Show Profit Info
input bool   ShowTime = true;          // Show Time Info

input group "=== ACCOUNT SETTINGS ==="
input bool   ShowAccountInfo = true;   // Show Account Information
input bool   ShowBalance = true;       // Show Account Balance
input bool   ShowEquity = true;        // Show Account Equity
input bool   ShowFreeMargin = true;    // Show Free Margin
input bool   ShowMarginLevel = true;   // Show Margin Level

input group "=== SYMBOL SETTINGS ==="
input bool   ShowSymbolInfo = true;    // Show Symbol Information
input bool   ShowBidAsk = true;        // Show Bid/Ask Prices
input bool   ShowHighLow = true;       // Show Daily High/Low
input bool   ShowSessionInfo = true;   // Show Session Information

//--- Global variables
string panelName = "KH_TradeMonitor_Panel";
datetime lastUpdate = 0;
int updateInterval = 1; // Update every second

//+------------------------------------------------------------------+
int OnInit()
{
   //--- Create the main panel com verificação de erros
   if(!CreateMainPanel())
   {
      Print("Error: Failed to create main panel");
      return(INIT_FAILED);
   }
   
   //--- Set timer for updates
   EventSetTimer(updateInterval);
   
   Print("KH Trade Monitor v2 MT5 initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Kill timer
   EventKillTimer();
   
   //--- Delete all objects
   DeleteAllObjects();
   
   Print("KH Trade Monitor v2 MT5 deinitialized");
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
   //--- Update display on new bar com verificação de tempo
   static datetime lastBarTime = 0;
   if(time[rates_total-1] != lastBarTime)
   {
      UpdateDisplay();
      lastBarTime = time[rates_total-1];
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
void OnTimer()
{
   //--- Update display every second
   UpdateDisplay();
}

//+------------------------------------------------------------------+
bool CreateMainPanel()
{
   //--- Create background rectangle
   string rectName = panelName + "_Background";
   if(!ObjectCreate(0, rectName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
      return false;
   
   ObjectSetInteger(0, rectName, OBJPROP_XDISTANCE, PanelX);
   ObjectSetInteger(0, rectName, OBJPROP_YDISTANCE, PanelY);
   ObjectSetInteger(0, rectName, OBJPROP_XSIZE, 300);
   ObjectSetInteger(0, rectName, OBJPROP_YSIZE, 400);
   ObjectSetInteger(0, rectName, OBJPROP_BGCOLOR, BackgroundColor);
   ObjectSetInteger(0, rectName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, rectName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, rectName, OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, rectName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, rectName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, rectName, OBJPROP_BACK, false);
   ObjectSetInteger(0, rectName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, rectName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, rectName, OBJPROP_HIDDEN, true);
   
   return true;
}

//+------------------------------------------------------------------+
void UpdateDisplay()
{
   int yOffset = 0;
   
   //--- Title
   CreateLabel("Title", "KH Trade Monitor v2", PanelX + 10, PanelY + 10 + yOffset, clrYellow);
   yOffset += 25;
   
   //--- Account Information
   if(ShowAccountInfo)
   {
      yOffset += 5;
      CreateLabel("AccountHeader", "=== ACCOUNT INFO ===", PanelX + 10, PanelY + 10 + yOffset, clrCyan);
      yOffset += 20;
      
      if(ShowBalance)
      {
         string balanceText = "Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2);
         CreateLabel("Balance", balanceText, PanelX + 15, PanelY + 10 + yOffset, TextColor);
         yOffset += 15;
      }
      
      if(ShowEquity)
      {
         string equityText = "Equity: " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2);
         CreateLabel("Equity", equityText, PanelX + 15, PanelY + 10 + yOffset, TextColor);
         yOffset += 15;
      }
      
      if(ShowFreeMargin)
      {
         string freeMarginText = "Free Margin: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2);
         CreateLabel("FreeMargin", freeMarginText, PanelX + 15, PanelY + 10 + yOffset, TextColor);
         yOffset += 15;
      }
      
      if(ShowMarginLevel)
      {
         double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
         string marginText = "Margin Level: " + DoubleToString(marginLevel, 2) + "%";
         color marginColor = (marginLevel > 100) ? clrLime : clrRed;
         CreateLabel("MarginLevel", marginText, PanelX + 15, PanelY + 10 + yOffset, marginColor);
         yOffset += 15;
      }
   }
   
   //--- Symbol Information
   if(ShowSymbolInfo)
   {
      yOffset += 5;
      CreateLabel("SymbolHeader", "=== SYMBOL INFO ===", PanelX + 10, PanelY + 10 + yOffset, clrCyan);
      yOffset += 20;
      
      string symbolText = "Symbol: " + _Symbol;
      CreateLabel("Symbol", symbolText, PanelX + 15, PanelY + 10 + yOffset, TextColor);
      yOffset += 15;
      
      if(ShowBidAsk)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         string bidText = "Bid: " + DoubleToString(bid, _Digits);
         string askText = "Ask: " + DoubleToString(ask, _Digits);
         
         CreateLabel("Bid", bidText, PanelX + 15, PanelY + 10 + yOffset, TextColor);
         yOffset += 15;
         CreateLabel("Ask", askText, PanelX + 15, PanelY + 10 + yOffset, TextColor);
         yOffset += 15;
      }
      
      if(ShowSpread)
      {
         long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
         string spreadText = "Spread: " + IntegerToString(spread) + " points";
         CreateLabel("Spread", spreadText, PanelX + 15, PanelY + 10 + yOffset, TextColor);
         yOffset += 15;
      }
      
      if(ShowHighLow)
      {
         double dayHigh = SymbolInfoDouble(_Symbol, SYMBOL_LASTHIGH);
         double dayLow = SymbolInfoDouble(_Symbol, SYMBOL_LASTLOW);
         string highText = "Day High: " + DoubleToString(dayHigh, _Digits);
         string lowText = "Day Low: " + DoubleToString(dayLow, _Digits);
         
         CreateLabel("DayHigh", highText, PanelX + 15, PanelY + 10 + yOffset, TextColor);
         yOffset += 15;
         CreateLabel("DayLow", lowText, PanelX + 15, PanelY + 10 + yOffset, TextColor);
         yOffset += 15;
      }
      
      if(ShowSessionInfo)
      {
         string sessionText = GetTradingSessionInfo();
         CreateLabel("SessionInfo", sessionText, PanelX + 15, PanelY + 10 + yOffset, TextColor);
         yOffset += 15;
      }
   }
   
   //--- Trading Information
   yOffset += 5;
   CreateLabel("TradingHeader", "=== TRADING INFO ===", PanelX + 10, PanelY + 10 + yOffset, clrCyan);
   yOffset += 20;
   
   int totalPositions = PositionsTotal();
   string positionsText = "Open Positions: " + IntegerToString(totalPositions);
   CreateLabel("Positions", positionsText, PanelX + 15, PanelY + 10 + yOffset, TextColor);
   yOffset += 15;
   
   if(ShowProfit)
   {
      double totalProfit = GetTotalProfit();
      string profitText = "Total Profit: " + DoubleToString(totalProfit, 2);
      color profitColor = (totalProfit >= 0) ? clrLime : clrRed;
      CreateLabel("TotalProfit", profitText, PanelX + 15, PanelY + 10 + yOffset, profitColor);
      yOffset += 15;
   }
   
   if(ShowSwap)
   {
      double totalSwap = GetTotalSwap();
      string swapText = "Total Swap: " + DoubleToString(totalSwap, 2);
      color swapColor = (totalSwap >= 0) ? clrLime : clrRed;
      CreateLabel("TotalSwap", swapText, PanelX + 15, PanelY + 10 + yOffset, swapColor);
      yOffset += 15;
   }
   
   if(ShowMargin)
   {
      double totalMargin = AccountInfoDouble(ACCOUNT_MARGIN);
      string marginText = "Used Margin: " + DoubleToString(totalMargin, 2);
      CreateLabel("UsedMargin", marginText, PanelX + 15, PanelY + 10 + yOffset, TextColor);
      yOffset += 15;
   }
   
   //--- Time Information
   if(ShowTime)
   {
      yOffset += 5;
      CreateLabel("TimeHeader", "=== TIME INFO ===", PanelX + 10, PanelY + 10 + yOffset, clrCyan);
      yOffset += 20;
      
      string serverTime = "Server Time: " + TimeToString(TimeCurrent(), TIME_SECONDS);
      CreateLabel("ServerTime", serverTime, PanelX + 15, PanelY + 10 + yOffset, TextColor);
      yOffset += 15;
      
      string localTime = "Local Time: " + TimeToString(TimeLocal(), TIME_SECONDS);
      CreateLabel("LocalTime", localTime, PanelX + 15, PanelY + 10 + yOffset, TextColor);
      yOffset += 15;
   }
   
   //--- Adjust panel height dynamically based on content com limite máximo para evitar overflow
   int panelHeight = MathMin(yOffset + 20, 600);  // Limite para 600px
   string rectName = panelName + "_Background";
   ObjectSetInteger(0, rectName, OBJPROP_YSIZE, panelHeight);
}

//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color textColor)
{
   string objectName = panelName + "_" + name;
   
   if(ObjectFind(0, objectName) < 0)
   {
      if(!ObjectCreate(0, objectName, OBJ_LABEL, 0, 0, 0))
         return;  // Falha silenciosa com log
      ObjectSetInteger(0, objectName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, objectName, OBJPROP_FONTSIZE, FontSize);
      ObjectSetString(0, objectName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, objectName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objectName, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, objectName, OBJPROP_HIDDEN, true);
   }
   
   ObjectSetInteger(0, objectName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objectName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, objectName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objectName, OBJPROP_COLOR, textColor);
}

//+------------------------------------------------------------------+
double GetTotalProfit()
{
   double totalProfit = 0.0;
   
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;  // Ticket inválido, skip
      
      if(PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         totalProfit += PositionGetDouble(POSITION_PROFIT);
      }
   }
   
   return totalProfit;
}

//+------------------------------------------------------------------+
double GetTotalSwap()
{
   double totalSwap = 0.0;
   
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;  // Ticket inválido, skip
      
      if(PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         totalSwap += PositionGetDouble(POSITION_SWAP);
      }
   }
   
   return totalSwap;
}

//+------------------------------------------------------------------+
void DeleteAllObjects()
{
   int total = ObjectsTotal(0, -1, -1);  // Todos os objetos em todas as janelas
   
   for(int i = total - 1; i >= 0; i--)
   {
      string objectName = ObjectName(0, i, -1, -1);
      if(StringFind(objectName, panelName) >= 0)
      {
         ObjectDelete(0, objectName);
      }
   }
}

//+------------------------------------------------------------------+
string GetAccountCurrency()
{
   return AccountInfoString(ACCOUNT_CURRENCY);
}

//+------------------------------------------------------------------+
string GetAccountCompany()
{
   return AccountInfoString(ACCOUNT_COMPANY);
}

//+------------------------------------------------------------------+
long GetAccountNumber()
{
   return AccountInfoInteger(ACCOUNT_LOGIN);
}

//+------------------------------------------------------------------+
bool IsMarketClosed()
{
   long tradeMode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   return (tradeMode == SYMBOL_TRADE_MODE_DISABLED);
}

//+------------------------------------------------------------------+
string GetTradingSessionInfo()
{
   datetime sessionStart, sessionEnd;
   
   if(SymbolInfoSessionTrade(_Symbol, MONDAY, 0, sessionStart, sessionEnd))
   {
      return "Session: " + TimeToString(sessionStart, TIME_MINUTES) + 
             " - " + TimeToString(sessionEnd, TIME_MINUTES);
   }
   
   return "Session: Unknown";
}
//+------------------------------------------------------------------+