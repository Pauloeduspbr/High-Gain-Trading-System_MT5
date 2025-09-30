//+------------------------------------------------------------------+
//|                                         HiGannActivator_MT5.mq5 |
//|                                         CORREÇÃO FINAL v1.03     |
//+------------------------------------------------------------------+

#property copyright "Hi Gann Activator MT5 Fixed"
#property version   "1.03"
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   5

#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepSkyBlue
#property indicator_width1  2
#property indicator_label1  "Gann Up"

#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_width2  2
#property indicator_label2  "Gann Down A"

#property indicator_type3   DRAW_LINE
#property indicator_color3  clrYellow
#property indicator_width3  2
#property indicator_label3  "Gann Down B"

#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrLime
#property indicator_width4  2
#property indicator_label4  "Buy Signal"

#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrRed
#property indicator_width5  2
#property indicator_label5  "Sell Signal"

//--- Inputs
input double Phase = 0;
input int    calcMode = 1;
input int    priceType = PRICE_MEDIAN;
input int    smooth = 5;
input bool   ShowArrows = true;
input double arrowsDistance = 1.0;
input bool   alertsOn = false;

//--- Buffers
double gannUp[];
double gannDownA[];
double gannDownB[];
double arrowUp[];
double arrowDown[];
double trendBuffer[];
double workBuffer[];
double hilbertBuffer[];

//--- Work arrays
double haWork[][4];
#define haClose 0
#define haOpen  1
#define haHigh  2
#define haLow   3

double workHil[][13];
#define _price     0
#define _smooth    1
#define _detrender 2
#define _period    3
#define _Q1        4
#define _I1        5
#define _JI        6
#define _JQ        7
#define _Q2        8
#define _I2        9
#define _Re       10
#define _Im       11
#define _res      12

double smoothWork[][40];
#define bsmax  5
#define bsmin  6
#define volty  7
#define vsum   8
#define avolty 9

#define Pi 3.14159265358979323846264338327950288

datetime lastBarTime = 0;
int validatedMode = 1;
static int lastArraySize = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, gannUp, INDICATOR_DATA);
   SetIndexBuffer(1, gannDownA, INDICATOR_DATA);
   SetIndexBuffer(2, gannDownB, INDICATOR_DATA);
   SetIndexBuffer(3, arrowUp, INDICATOR_DATA);
   SetIndexBuffer(4, arrowDown, INDICATOR_DATA);
   SetIndexBuffer(5, trendBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, workBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, hilbertBuffer, INDICATOR_CALCULATIONS);
   
   PlotIndexSetInteger(3, PLOT_ARROW, 241);
   PlotIndexSetInteger(4, PLOT_ARROW, 242);
   
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   ArraySetAsSeries(gannUp, true);
   ArraySetAsSeries(gannDownA, true);
   ArraySetAsSeries(gannDownB, true);
   ArraySetAsSeries(arrowUp, true);
   ArraySetAsSeries(arrowDown, true);
   ArraySetAsSeries(trendBuffer, true);
   
   validatedMode = (calcMode >= 1 && calcMode <= 3) ? calcMode : 1;
   lastArraySize = 0;
   
   if(!ShowArrows)
   {
      PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_NONE);
   }
   
   IndicatorSetString(INDICATOR_SHORTNAME, "Hi Gann (" + 
                     IntegerToString(validatedMode) + "," + IntegerToString(smooth) + ")");
   
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
   if(rates_total < 100) return(0);
      
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   //--- OTIMIZAÇÃO: Resize arrays apenas quando necessário
   if(lastArraySize != rates_total)
   {
      ArrayResize(haWork, rates_total);
      ArrayResize(workHil, rates_total);
      ArrayResize(smoothWork, rates_total);
      lastArraySize = rates_total;
   }
   
   //--- OTIMIZAÇÃO: Determinar intervalo de cálculo
   int start;
   int limit;
   
   if(prev_calculated == 0)
   {
      start = 0;
      limit = rates_total;
      
      // Limpar buffers apenas na primeira execução
      ArrayInitialize(trendBuffer, 1);
      ArrayInitialize(gannUp, EMPTY_VALUE);
      ArrayInitialize(gannDownA, EMPTY_VALUE);
      ArrayInitialize(gannDownB, EMPTY_VALUE);
      ArrayInitialize(arrowUp, EMPTY_VALUE);
      ArrayInitialize(arrowDown, EMPTY_VALUE);
   }
   else
   {
      // OTIMIZAÇÃO: Calcular apenas barras novas + buffer pequeno
      start = MathMax(prev_calculated - 2, 50);
      limit = rates_total;
      
      // Se não há barras novas, pular
      if(rates_total - prev_calculated <= 0)
         return(rates_total);
   }
   
   //--- OTIMIZAÇÃO: Limitar processamento máximo
   int maxBarsPerTick = 50;
   if(limit - start > maxBarsPerTick)
   {
      limit = start + maxBarsPerTick;
   }
   
   //--- Loop principal
   for(int i = start; i < limit; i++)
   {
      int r = i;
      int pos = rates_total - 1 - i;
      
      if(pos < 0 || pos >= rates_total) continue;
      
      //--- Inicializar primeira barra
      if(i == 0)
      {
         double p = GetPrice(priceType, pos, open, high, low, close);
         
         haWork[0][haOpen] = (open[pos] + close[pos]) / 2.0;
         haWork[0][haClose] = (open[pos] + close[pos] + high[pos] + low[pos]) / 4.0;
         haWork[0][haHigh] = high[pos];
         haWork[0][haLow] = low[pos];
         
         for(int k = 0; k < 13; k++) workHil[0][k] = p;
         for(int k = 0; k < 40; k++) smoothWork[0][k] = p;
         
         gannUp[pos] = p;
         trendBuffer[pos] = 1;
         gannDownA[pos] = EMPTY_VALUE;
         gannDownB[pos] = EMPTY_VALUE;
         arrowUp[pos] = EMPTY_VALUE;
         arrowDown[pos] = EMPTY_VALUE;
         continue;
      }
      
      //--- Pular se histórico insuficiente
      if(i < 50) 
      {
         gannUp[pos] = GetPrice(priceType, pos, open, high, low, close);
         trendBuffer[pos] = 1;
         gannDownA[pos] = EMPTY_VALUE;
         gannDownB[pos] = EMPTY_VALUE;
         arrowUp[pos] = EMPTY_VALUE;
         arrowDown[pos] = EMPTY_VALUE;
         continue;
      }
      
      //--- Cálculos principais
      double priceValue = GetPrice(priceType, pos, open, high, low, close);
      double Length = MathMax(CalculateHilbert(priceValue, validatedMode, smooth, r) / 2.0, 1);
      
      double maOpen = CalculateSmooth(open[pos], Length, Phase, r, 0);
      double maClose = CalculateSmooth(close[pos], Length, Phase, r, 10);
      double maLow = CalculateSmooth(low[pos], Length, Phase, r, 20);
      double maHigh = CalculateSmooth(high[pos], Length, Phase, r, 30);
      
      //--- Heiken Ashi
      haWork[r][haOpen] = (haWork[r-1][haOpen] + haWork[r-1][haClose]) / 2.0;
      haWork[r][haClose] = (maOpen + maHigh + maLow + maClose) / 4.0;
      haWork[r][haHigh] = MathMax(maHigh, MathMax(haWork[r][haOpen], haWork[r][haClose]));
      haWork[r][haLow] = MathMin(maLow, MathMin(haWork[r][haOpen], haWork[r][haClose]));
      
      //--- Limpar buffers
      gannDownA[pos] = EMPTY_VALUE;
      gannDownB[pos] = EMPTY_VALUE;
      arrowUp[pos] = EMPTY_VALUE;
      arrowDown[pos] = EMPTY_VALUE;
      
      //--- Determinar tendência
      int posPrev = MathMin(pos + 1, rates_total - 1);
      trendBuffer[pos] = trendBuffer[posPrev];
      
      if(close[pos] > haWork[r-1][haHigh]) trendBuffer[pos] = 1;
      if(close[pos] < haWork[r-1][haLow]) trendBuffer[pos] = -1;
      
      //--- Setas em mudanças de tendência
      if(trendBuffer[pos] != trendBuffer[posPrev])
      {
         double atr = CalculateATR(pos, 20, high, low, close);
         
         if(trendBuffer[pos] == 1)
            arrowUp[pos] = low[pos] - arrowsDistance * atr;
            
         if(trendBuffer[pos] == -1)
            arrowDown[pos] = high[pos] + arrowsDistance * atr;
      }
      
      //--- Linha Gann
      if(trendBuffer[pos] == 1)
         gannUp[pos] = haWork[r-1][haLow];
      else
         gannUp[pos] = haWork[r-1][haHigh];
      
      //--- Plot colorido
      if(trendBuffer[pos] == -1)
         PlotPoint(pos, gannDownA, gannDownB, gannUp);
   }
   
   //--- Alertas menos frequentes
   static int alertCounter = 0;
   if(alertsOn && (++alertCounter % 10 == 0))
      CheckAlerts(time);
   
   return(rates_total);
}

//+------------------------------------------------------------------+
double CalculateSmooth(double price, double len, double ph, int r, int s)
{
   if(r < 10 || r >= ArrayRange(smoothWork, 0)) return price;
   
   int r1 = r - 1;
   int r10 = r - 10;
   
   double len1 = MathMax(MathLog(MathSqrt(0.5 * (len - 1))) / MathLog(2.0) + 2.0, 0);
   double pow1 = MathMax(len1 - 2.0, 0.5);
   double del1 = price - smoothWork[r1][bsmax + s];
   double del2 = price - smoothWork[r1][bsmin + s];
   
   smoothWork[r][volty + s] = MathMax(MathAbs(del1), MathAbs(del2));
   smoothWork[r][vsum + s] = smoothWork[r1][vsum + s] + 
                            0.1 * (smoothWork[r][volty + s] - smoothWork[r10][volty + s]);
   
   // OTIMIZAÇÃO MÍNIMA: Reduzir avgLen máximo
   double avgLen = MathMin(MathMax(4.0 * len, 30), 100); // Era 150
   double avg = 0;
   
   if(r < avgLen)
   {
      int maxK = MathMin(r + 1, (int)avgLen);
      for(int k = 0; k < maxK; k++)
         avg += smoothWork[r - k][vsum + s];
      avg /= maxK;
   }
   else
   {
      int rAvg = (int)(r - avgLen);
      avg = (smoothWork[r1][avolty + s] * avgLen - smoothWork[rAvg][vsum + s] + 
            smoothWork[r][vsum + s]) / avgLen;
   }
   
   smoothWork[r][avolty + s] = avg;
   
   double dVolty = (avg > 0) ? smoothWork[r][volty + s] / avg : 1.0;
   dVolty = MathMin(dVolty, MathPow(len1, 1.0 / pow1));
   dVolty = MathMax(dVolty, 1.0);
   
   double pow2 = MathPow(dVolty, pow1);
   double len2 = MathSqrt(0.5 * (len - 1)) * len1;
   double Kv = MathPow(len2 / (len2 + 1), MathSqrt(pow2));
   
   smoothWork[r][bsmax + s] = (del1 > 0) ? price : price - Kv * del1;
   smoothWork[r][bsmin + s] = (del2 < 0) ? price : price - Kv * del2;
   
   double R = MathMax(MathMin(ph, 100), -100) / 100.0 + 1.5;
   double beta = 0.45 * (len - 1) / (0.45 * (len - 1) + 2);
   double alpha = MathPow(beta, pow2);
   
   smoothWork[r][0 + s] = price + alpha * (smoothWork[r1][0 + s] - price);
   smoothWork[r][1 + s] = (price - smoothWork[r][0 + s]) * (1 - beta) + beta * smoothWork[r1][1 + s];
   smoothWork[r][2 + s] = smoothWork[r][0 + s] + R * smoothWork[r][1 + s];
   smoothWork[r][3 + s] = (smoothWork[r][2 + s] - smoothWork[r1][4 + s]) * MathPow(1 - alpha, 2) + 
                         MathPow(alpha, 2) * smoothWork[r1][3 + s];
   smoothWork[r][4 + s] = smoothWork[r1][4 + s] + smoothWork[r][3 + s];
   
   return smoothWork[r][4 + s];
}

//+------------------------------------------------------------------+
double GetPrice(int pt, int pos, const double &o[], const double &h[], 
                const double &l[], const double &c[])
{
   switch(pt)
   {
      case PRICE_OPEN:     return o[pos];
      case PRICE_HIGH:     return h[pos];
      case PRICE_LOW:      return l[pos];
      case PRICE_CLOSE:    return c[pos];
      case PRICE_MEDIAN:   return (h[pos] + l[pos]) / 2.0;
      case PRICE_TYPICAL:  return (h[pos] + l[pos] + c[pos]) / 3.0;
      case PRICE_WEIGHTED: return (h[pos] + l[pos] + 2 * c[pos]) / 4.0;
      default:             return (h[pos] + l[pos]) / 2.0;
   }
}

//+------------------------------------------------------------------+
double CalculateHilbert(double price, int mode, double sp, int r)
{
   if(r < 10 || r >= ArrayRange(workHil, 0)) return 35.0;
   
   int r1 = r - 1;
   int r2 = r - 2;
   int r3 = r - 3;
   
   workHil[r][_price] = price;
   workHil[r][_smooth] = (4.0 * workHil[r][_price] + 3.0 * workHil[r1][_price] + 
                         2.0 * workHil[r2][_price] + workHil[r3][_price]) / 10.0;
   
   workHil[r][_detrender] = CalcComp(r, _smooth);
   workHil[r][_Q1] = CalcComp(r, _detrender);
   workHil[r][_I1] = workHil[r3][_detrender];
   workHil[r][_JI] = CalcComp(r, _I1);
   workHil[r][_JQ] = CalcComp(r, _Q1);
   
   workHil[r][_I2] = 0.2 * (workHil[r][_I1] - workHil[r][_JQ]) + 0.8 * workHil[r1][_I2];
   workHil[r][_Q2] = 0.2 * (workHil[r][_Q1] + workHil[r][_JI]) + 0.8 * workHil[r1][_Q2];
   workHil[r][_Re] = 0.2 * (workHil[r][_I2] * workHil[r1][_I2] + 
                           workHil[r][_Q2] * workHil[r1][_Q2]) + 0.8 * workHil[r1][_Re];
   workHil[r][_Im] = 0.2 * (workHil[r][_I2] * workHil[r1][_Q2] - 
                           workHil[r][_Q2] * workHil[r1][_I2]) + 0.8 * workHil[r1][_Im];
   
   if(workHil[r][_Re] != 0 && workHil[r][_Im] != 0)
      workHil[r][_period] = 2.0 * Pi / MathAbs(MathArctan(workHil[r][_Im] / workHil[r][_Re]));
   else
      workHil[r][_period] = workHil[r1][_period];
      
   workHil[r][_period] = MathMin(workHil[r][_period], 1.50 * workHil[r1][_period]);
   workHil[r][_period] = MathMax(workHil[r][_period], 0.67 * workHil[r1][_period]);
   workHil[r][_period] = MathMin(MathMax(workHil[r][_period], 6), 50);
   workHil[r][_period] = 0.2 * workHil[r][_period] + 0.8 * workHil[r1][_period];
   
   double alpha = 2.0 / (1.0 + MathMax(sp, 1));
   
   switch(mode)
   {
      case 1:
         workHil[r][_res] = workHil[r1][_res] + alpha * (workHil[r][_period] - workHil[r1][_res]);
         break;
      case 2:
         {
            double damp = MathSqrt(workHil[r][_Re] * workHil[r][_Re] + 
                                  workHil[r][_Im] * workHil[r][_Im]) / _Point;
            workHil[r][_res] = workHil[r1][_res] + alpha * (damp - workHil[r1][_res]);
         }
         break;
      case 3:
         {
            double ph = (workHil[r][_I1] != 0) ? 
                       180.0 / Pi * MathArctan(workHil[r][_Q1] / workHil[r][_I1]) : 180.0;
            workHil[r][_res] = workHil[r1][_res] + alpha * (ph - workHil[r1][_res]);
         }
         break;
   }
   
   return workHil[r][_res];
}

//+------------------------------------------------------------------+
double CalcComp(int r, int from)
{
   if(r < 6) return 0;
   
   return (0.0962 * workHil[r][from] + 
           0.5769 * workHil[r-2][from] - 
           0.5769 * workHil[r-4][from] - 
           0.0962 * workHil[r-6][from]) * 
          (0.075 * workHil[r-1][_period] + 0.54);
}

//+------------------------------------------------------------------+
double CalculateATR(int pos, int period, const double &h[], const double &l[], const double &c[])
{
   double atr = 0;
   int cnt = 0;
   
   for(int i = 0; i < period && (pos + i) < ArraySize(h); i++)
   {
      double tr = h[pos + i] - l[pos + i];
      if((pos + i + 1) < ArraySize(c))
      {
         tr = MathMax(tr, MathAbs(h[pos + i] - c[pos + i + 1]));
         tr = MathMax(tr, MathAbs(l[pos + i] - c[pos + i + 1]));
      }
      atr += tr;
      cnt++;
   }
   
   return (cnt > 0) ? atr / cnt : 0.0001;
}

//+------------------------------------------------------------------+
void PlotPoint(int i, double &f[], double &s[], double &from[])
{
   if((i + 1) >= ArraySize(f)) return;
   
   if(f[i+1] == EMPTY_VALUE)
   {
      if(((i+2) < ArraySize(f)) && (f[i+2] == EMPTY_VALUE))
      {
         f[i] = from[i];
         f[i+1] = from[i+1];
         s[i] = EMPTY_VALUE;
      }
      else
      {
         s[i] = from[i];
         s[i+1] = from[i+1];
         f[i] = EMPTY_VALUE;
      }
   }
   else
   {
      f[i] = from[i];
      s[i] = EMPTY_VALUE;
   }
}

//+------------------------------------------------------------------+
void CheckAlerts(const datetime &time[])
{
   if(!alertsOn) return;
   
   datetime curr = time[0];
   if(curr == lastBarTime) return;
   lastBarTime = curr;
   
   if(ArraySize(trendBuffer) < 2) return;
   
   if(trendBuffer[0] != trendBuffer[1])
   {
      string msg = _Symbol + " Hi Gann: " + 
                  ((trendBuffer[0] == 1) ? "BUY" : "SELL");
      Alert(msg);
   }
}

//+------------------------------------------------------------------+
void CleanPoint(int i, double &first[], double &second[])
{
   if(i + 1 >= ArraySize(first)) return;
   
   if((second[i] != EMPTY_VALUE) && (second[i + 1] != EMPTY_VALUE))
      second[i + 1] = EMPTY_VALUE;
   else if((first[i] != EMPTY_VALUE) && (first[i + 1] != EMPTY_VALUE) && 
           (i + 2 < ArraySize(first)) && (first[i + 2] == EMPTY_VALUE))
      first[i + 1] = EMPTY_VALUE;
}

//+------------------------------------------------------------------+
int GetTrendDirection(int shift = 0)
{
   return (shift < ArraySize(trendBuffer)) ? (int)trendBuffer[shift] : 0;
}

//+------------------------------------------------------------------+
double GetGannValue(int shift = 0)
{
   return (shift < ArraySize(gannUp)) ? gannUp[shift] : 0;
}

//+------------------------------------------------------------------+
bool IsTrendChange(int shift = 0)
{
   return ((shift + 1) < ArraySize(trendBuffer)) ? 
          (trendBuffer[shift] != trendBuffer[shift + 1]) : false;
}