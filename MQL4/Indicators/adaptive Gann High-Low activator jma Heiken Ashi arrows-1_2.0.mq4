//+------------------------------------------------------------------+
//|                                          Gann high-low activator |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "www.forex-tsd.com"
#property link      "www.forex-tsd.com"

#property indicator_chart_window
#property indicator_buffers 5
#property indicator_color1  DeepSkyBlue
#property indicator_color2  Red//PaleVioletRed
#property indicator_color3  Yellow//PaleVioletRed
#property indicator_color4  DeepSkyBlue
#property indicator_color5  PaleVioletRed
#property indicator_width1  2
#property indicator_width2  2
#property indicator_width3  2
#property indicator_width4  1
#property indicator_width5  1

//
//
//
//
//

extern string TimeFrame       = "Current time frame";
extern double Phase           = 0;
extern int    mode            = 1;
extern int    price           = PRICE_MEDIAN;
extern int    smooth          = 5;
extern bool   ShowArrows      = false;
extern double arrowsDistance  = 1.0;
extern bool   alertsOn        = false;
extern bool   alertsOnCurrent = true;
extern bool   alertsMessage   = true;
extern bool   alertsSound     = false;
extern bool   alertsEmail     = false;
extern bool   Interpolate     = true;
extern string sV = " -- Show Indi Value -- ";
extern bool   ShowValue       = false;
extern color  TextColor       = White;
extern int    FontSize        = 9;
extern string FontName        = "Verdana";

//
//
//
//
//

double gup[];
double gdna[];
double gdnb[];
double arrowUp[];
double arrowDn[];
double trend[];
double lastV;
string displaystr;

//
//
//
//
//

int    timeFrame;
string indicatorFileName;
bool   returnBars;
bool   calculateValue;

//+------------------------------------------------------------------
//|                                                                  
//+------------------------------------------------------------------
//
//
//
//
//

int init()
{
   IndicatorBuffers(6);
   SetIndexBuffer(0,gup);
   SetIndexBuffer(1,gdna);
   SetIndexBuffer(2,gdnb);
   SetIndexBuffer(3,arrowUp);
   SetIndexBuffer(4,arrowDn);
   SetIndexBuffer(5,trend);
   
   mode = MathMax(MathMin(mode,3),1);
   
      //
      //
      //
      //
      //
      
         indicatorFileName = WindowExpertName();
         calculateValue    = (TimeFrame=="calculateValue"); if (calculateValue) return(0);
         returnBars        = (TimeFrame=="returnBars");     if (returnBars)     return(0);
         timeFrame         = stringToTimeFrame(TimeFrame);
         if (ShowArrows)
         {
             SetIndexStyle(3,DRAW_ARROW); SetIndexArrow(3,241);
             SetIndexStyle(4,DRAW_ARROW); SetIndexArrow(4,242);
         }
         else
         {
             SetIndexStyle(3,DRAW_NONE);
             SetIndexStyle(4,DRAW_NONE);
         }
      
      //
      //
      //
      //
      //
      
   IndicatorShortName(timeFrameToString(timeFrame)+" Gann high/low activator - HeikenAshi");
         
   return(0);
}

int deinit() 
{
   ObjectDelete("V_Label");
   return(0);
}
//+------------------------------------------------------------------
//|                                                                  
//+------------------------------------------------------------------
//
//
//
//
//

double work[][4];
#define haClose 0
#define haOpen  1
#define haHigh  2
#define haLow   3

//
//
//
//
//

int start()
{
   int i,r,limit,counted_bars=IndicatorCounted();

   if(counted_bars<0) return(-1);
   if(counted_bars>0) counted_bars--;
           limit=MathMin(Bars-counted_bars,Bars-1);
           if (returnBars) { gup[0] = limit+1; return(0); }

   //
   //
   //
   //
   //

   if (calculateValue || timeFrame == Period())
   {
      if (ArrayRange(work,0)!=Bars) ArrayResize(work,Bars);
      if (!calculateValue && trend[limit]==-1) CleanPoint(limit,gdna,gdnb);
      for(i=limit, r=Bars-i-1;i>=0;i--,r++)
      {
         if (r==0)
         {
            work[r][haOpen]  = (Open[i]+Close[i])/2.0;
            work[r][haClose] = (Open[i]+Close[i]+High[i]+Low[i])/4.0;
            work[r][haHigh]  = High[i];
            work[r][haLow]   = Low[i];
            continue;
         }
         
         //
         //
         //
         //
         //
            double Length  = MathMax(iHilbert(iMA(NULL,0,1,0,MODE_SMA,price,i),mode,smooth,i)/2,1);
            double maOpen  = iSmooth(Open[i], Length,Phase,i, 0);
            double maClose = iSmooth(Close[i],Length,Phase,i,10);
            double maLow   = iSmooth(Low[i],  Length,Phase,i,20);
            double maHigh  = iSmooth(High[i], Length,Phase,i,30);

            //
            //
            //
            //
            //
               
               work[r][haOpen]  = (work[r-1][haOpen]+work[r-1][haClose])/2.0;
               work[r][haClose] = (maOpen+maHigh+maLow+maClose)/4.0;
               work[r][haHigh]  = MathMax(maHigh,MathMax(work[r][haOpen],work[r][haClose]));
               work[r][haLow]   = MathMin(maLow ,MathMin(work[r][haOpen],work[r][haClose]));

            //
            //
            //
            //

               gdna[i]    = EMPTY_VALUE;
               gdnb[i]    = EMPTY_VALUE;
               arrowUp[i] = EMPTY_VALUE;
               arrowDn[i] = EMPTY_VALUE;
               trend[i] = trend[i+1];
                  if(Close[i]>work[r-1][haHigh]) trend[i] =  1;
                  if(Close[i]<work[r-1][haLow] ) trend[i] = -1;
                  if(trend[i]!=trend[i+1])
                  { 
                     if(trend[i] ==  1) arrowUp[i] = Low[i] -arrowsDistance*iATR(NULL,0,20,i);
                     if(trend[i] == -1) arrowDn[i] = High[i]+arrowsDistance*iATR(NULL,0,20,i);
                  }                     
                  if(trend[i] == -1)
                        gup[i] = work[r-1][haHigh];
                  else  gup[i] = work[r-1][haLow];
                  if (!calculateValue && trend[i]==-1) PlotPoint(i,gdna,gdnb,gup);
                              
      }

      //
      //
      //
      //
      //
      
      manageAlerts();
      //
      ShowIndiVal();
      return(0);
   }      

   //
   //
   //
   //
   //
   
   limit = MathMax(limit,MathMin(Bars-1,iCustom(NULL,timeFrame,indicatorFileName,"returnBars",0,0)*timeFrame/Period()));
   if (trend[limit]==-1) CleanPoint(limit,gdna,gdnb);
   for(i=limit; i>=0; i--)
   {
      int y = iBarShift(NULL,timeFrame,Time[i]);
         gdna[i]  = EMPTY_VALUE;
         gdnb[i]  = EMPTY_VALUE;
         gup[i]   = iCustom(NULL,timeFrame,indicatorFileName,"calculateValue",Phase,mode,price,smooth,0,y);
         trend[i] = iCustom(NULL,timeFrame,indicatorFileName,"calculateValue",Phase,mode,price,smooth,5,y);
         if(trend[i]!=trend[i+1])
            { 
               if(trend[i] ==  1) arrowUp[i] = Low[i] -iATR(NULL,0,20,i);
               if(trend[i] == -1) arrowDn[i] = High[i]+iATR(NULL,0,20,i);
            }                     
            
         //
         //
         //
         //
         //
      
         if (timeFrame <= Period() || y==iBarShift(NULL,timeFrame,Time[i-1])) continue;
         if (!Interpolate) continue;

         //
         //
         //
         //
         //

         datetime time = iTime(NULL,timeFrame,y);
            for(int n = 1; i+n < Bars && Time[i+n] >= time; n++) continue;	
            for(int k = 1; k < n; k++)
               gup[i+k] = gup[i] + (gup[i+n]-gup[i])*k/n;
   }
   for (i=limit;i>=0;i--) if (trend[i]==-1) PlotPoint(i,gdna,gdnb,gup);

   //
   //
   //
   //
   //
   
   manageAlerts();
   //
   ShowIndiVal();
   return(0);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//
//
//
//
//

void manageAlerts()
{
   if (!calculateValue && alertsOn)
   {
      if (alertsOnCurrent)
           int whichBar = 0;
      else     whichBar = 1; whichBar = iBarShift(NULL,0,iTime(NULL,timeFrame,whichBar));
      if (trend[whichBar] != trend[whichBar+1])
      {
         if (trend[whichBar] == 1) doAlert(whichBar,"up");
         if (trend[whichBar] ==-1) doAlert(whichBar,"down");
      }         
   }
}   

//
//
//
//
//

void doAlert(int forBar, string doWhat)
{
   static string   previousAlert="nothing";
   static datetime previousTime;
   string message;
   
      if (previousAlert != doWhat || previousTime != Time[forBar]) {
          previousAlert  = doWhat;
          previousTime   = Time[forBar];

          //
          //
          //
          //
          //

          message =  StringConcatenate(Symbol()," at ",TimeToStr(TimeLocal(),TIME_SECONDS)," Gann HL activator trend changed to ",doWhat);
             if (alertsMessage) Alert(message);
             if (alertsEmail)   SendMail(StringConcatenate(Symbol(),"Gann HL "),message);
             if (alertsSound)   PlaySound("alert2.wav");
      }
}

//+-------------------------------------------------------------------
//|                                                                  
//+-------------------------------------------------------------------
//
//
//
//
//

string sTfTable[] = {"M1","M5","M15","M30","H1","H4","D1","W1","MN"};
int    iTfTable[] = {1,5,15,30,60,240,1440,10080,43200};

//
//
//
//
//

int stringToTimeFrame(string tfs)
{
   tfs = stringUpperCase(tfs);
   for (int i=ArraySize(iTfTable)-1; i>=0; i--)
         if (tfs==sTfTable[i] || tfs==""+iTfTable[i]) return(MathMax(iTfTable[i],Period()));
                                                      return(Period());
}
string timeFrameToString(int tf)
{
   for (int i=ArraySize(iTfTable)-1; i>=0; i--) 
         if (tf==iTfTable[i]) return(sTfTable[i]);
                              return("");
}

//
//
//
//
//

string stringUpperCase(string str)
{
   string   s = str;

   for (int length=StringLen(str)-1; length>=0; length--)
   {
      int char = StringGetChar(s, length);
         if((char > 96 && char < 123) || (char > 223 && char < 256))
                     s = StringSetChar(s, length, char - 32);
         else if(char > -33 && char < 0)
                     s = StringSetChar(s, length, char + 224);
   }
   return(s);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//
//
//
//
//

void CleanPoint(int i,double& first[],double& second[])
{
   if ((second[i]  != EMPTY_VALUE) && (second[i+1] != EMPTY_VALUE))
        second[i+1] = EMPTY_VALUE;
   else
      if ((first[i] != EMPTY_VALUE) && (first[i+1] != EMPTY_VALUE) && (first[i+2] == EMPTY_VALUE))
          first[i+1] = EMPTY_VALUE;
}

//
//
//
//
//

void PlotPoint(int i,double& first[],double& second[],double& from[])
{
   if (first[i+1] == EMPTY_VALUE)
      {
         if (first[i+2] == EMPTY_VALUE) {
                first[i]   = from[i];
                first[i+1] = from[i+1];
                second[i]  = EMPTY_VALUE;
            }
         else {
                second[i]   =  from[i];
                second[i+1] =  from[i+1];
                first[i]    = EMPTY_VALUE;
            }
      }
   else
      {
         first[i]  = from[i];
         second[i] = EMPTY_VALUE;
      }
}


double wrk[][40];

#define bsmax  5
#define bsmin  6
#define volty  7
#define vsum   8
#define avolty 9

//
//
//
//
//

double iSmooth(double price, double length, double phase, int i, int s=0)
{
   if (ArrayRange(wrk,0) != Bars) ArrayResize(wrk,Bars);
   
   int r = Bars-i-1; 
      if (r==0) { for(int k=0; k<7; k++) wrk[0][k+s]= price; for(; k<10; k++) wrk[0][k+s]= 0; return(price); }

   //
   //
   //
   //
   //
   
      double len1 = MathMax(MathLog(MathSqrt(0.5*(length-1)))/MathLog(2.0)+2.0,0);
      double pow1 = MathMax(len1-2.0,0.5);
      double del1 = price - wrk[r-1][bsmax+s];
      double del2 = price - wrk[r-1][bsmin+s];
	
         wrk[r][volty+s] = 0;
               if(MathAbs(del1) > MathAbs(del2)) wrk[r][volty+s] = MathAbs(del1); 
               if(MathAbs(del1) < MathAbs(del2)) wrk[r][volty+s] = MathAbs(del2); 
         wrk[r][vsum+s] =	wrk[r-1][vsum+s] + 0.1*(wrk[r][volty+s]-wrk[r-10][volty+s]);
   
         //
         //
         //
         //
         //
      
         double avgLen = MathMin(MathMax(4.0*length,30),150);
            if (r<avgLen)
            {
               double avg = wrk[r][vsum+s];  for (k=1; k<avgLen && (r-k)>=0 ; k++) avg += wrk[r-k][vsum+s];
                                                                                   avg /= k;
            }
            else avg = (wrk[r-1][avolty+s]*avgLen-wrk[r-toInt(avgLen)][vsum+s]+wrk[r][vsum+s])/avgLen;
            
         //
         //
         //
         //
         //
                                                           
         wrk[r][avolty+s] = avg;                                           
            if (wrk[r][avolty+s] > 0)
               double dVolty = wrk[r][volty+s]/wrk[r][avolty+s]; else dVolty = 0;   
	               if (dVolty > MathPow(len1,1.0/pow1)) dVolty = MathPow(len1,1.0/pow1);
                  if (dVolty < 1)                      dVolty = 1.0;

      //
      //
      //
      //
      //
	        
   	double pow2 = MathPow(dVolty, pow1);
      double len2 = MathSqrt(0.5*(length-1))*len1;
      double Kv   = MathPow(len2/(len2+1), MathSqrt(pow2));		
	
         if (del1 > 0) wrk[r][bsmax+s] = price; else wrk[r][bsmax+s] = price - Kv*del1;
         if (del2 < 0) wrk[r][bsmin+s] = price; else wrk[r][bsmin+s] = price - Kv*del2;

   //
   //
   //
   //
   //

      double R     = MathMax(MathMin(phase,100),-100)/100.0 + 1.5;
      double beta  = 0.45*(length-1)/(0.45*(length-1)+2);
      double alpha = MathPow(beta,pow2);

         wrk[r][0+s] = price + alpha*(wrk[r-1][0+s]-price);
         wrk[r][1+s] = (price - wrk[r][0+s])*(1-beta) + beta*wrk[r-1][1+s];
         wrk[r][2+s] = (wrk[r][0+s] + R*wrk[r][1+s]);
         wrk[r][3+s] = (wrk[r][2+s] - wrk[r-1][4+s])*MathPow((1-alpha),2) + MathPow(alpha,2)*wrk[r-1][3+s];
         wrk[r][4+s] = (wrk[r-1][4+s] + wrk[r][3+s]); 

   //
   //
   //
   //
   //

   return(wrk[r][4+s]);
}
int toInt(double value) { return(value); }   


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

#define Pi 3.14159265358979323846264338327950288

//
//
//
//
//

double iHilbert(double price, int mode, double smooth, int i, int s=0)
{
   if (ArrayRange(workHil,0)!=Bars) ArrayResize(workHil,Bars);
   int r = Bars-i-1; s = s*13;
      
   //
   //
   //
   //
   //
      
      workHil[r][s+_price]     = price;
      workHil[r][s+_smooth]    = (4.0*workHil[r][s+_price]+3.0*workHil[r-1][s+_price]+2.0*workHil[r-2][s+_price]+workHil[r-3][s+_price])/10.0;
      workHil[r][s+_detrender] = calcComp(r,_smooth,s);
      workHil[r][s+_Q1]        = calcComp(r,_detrender,s);
      workHil[r][s+_I1]        = workHil[r-3][s+_detrender];
      workHil[r][s+_JI]        = calcComp(r,_I1,s);
      workHil[r][s+_JQ]        = calcComp(r,_Q1,s);

      workHil[r][s+_I2]        = 0.2*(workHil[r][s+_I1]-workHil[r][s+_JQ])                                         + 0.8*workHil[r-1][s+_I2];
      workHil[r][s+_Q2]        = 0.2*(workHil[r][s+_Q1]+workHil[r][s+_JI])                                         + 0.8*workHil[r-1][s+_Q2];
      workHil[r][s+_Re]        = 0.2*(workHil[r][s+_I2]*workHil[r-1][s+_I2]+workHil[r][s+_Q2]*workHil[r-1][s+_Q2]) + 0.8*workHil[r-1][s+_Re];
      workHil[r][s+_Im]        = 0.2*(workHil[r][s+_I2]*workHil[r-1][s+_Q2]-workHil[r][s+_Q2]*workHil[r-1][s+_I2]) + 0.8*workHil[r-1][s+_Im];

      if (workHil[r][s+_Re]!= 0 && workHil[r][s+_Im]!=0) 
          workHil[r][s+_period] = 2.0*Pi/(MathArctan(workHil[r][s+_Im]/workHil[r][s+_Re]));
          workHil[r][s+_period] = MathMin(workHil[r][s+_period],1.50*workHil[r-1][s+_period]);
          workHil[r][s+_period] = MathMax(workHil[r][s+_period],0.67*workHil[r-1][s+_period]);
          workHil[r][s+_period] = MathMin(MathMax(workHil[r][s+_period],6),50);
          workHil[r][s+_period] = 0.2*workHil[r][s+_period]+0.8*workHil[r-1][s+_period];

   //
   //
   //
   //
   //

   double alpha = 2.0/(1.0+MathMax(smooth,1));
   switch (mode)
   {
      case 1 : 
            workHil[r][s+_res] = workHil[r-1][s+_res]+alpha*(workHil[r][s+_period]-workHil[r-1][s+_res]);
            break;
            
      //
      //
      //
      //
      //
                  
      case 2 :
            double damp = MathSqrt(workHil[r][s+_Re]*workHil[r][s+_Re] + workHil[r][s+_Im]*workHil[r][s+_Im])/Point;
                                   workHil[r][s+_res] = workHil[r-1][s+_res]+alpha*(damp-workHil[r-1][s+_res]); 
            break;
            
      //
      //
      //
      //
      //
                  
      case 3 : 
            double phase;
               if (workHil[r][s+_I1] != 0.0) 
                     phase = 180.0/Pi*MathArctan(workHil[r][s+_Q1]/workHil[r][s+_I1]);
               else  phase = 180.0;
            workHil[r][s+_res] = workHil[r-1][s+_res]+alpha*(phase-workHil[r-1][s+_res]);
            break;
   }         
   return (workHil[r][s+_res]);
}

//
//
//
//
//

double calcComp(int r, int from, int s)
{
   return((0.0962*workHil[r  ][s+from] + 
           0.5769*workHil[r-2][s+from] - 
           0.5769*workHil[r-4][s+from] - 
           0.0962*workHil[r-6][s+from]) * (0.075*workHil[r-1][s+_period] + 0.54));
}

void ShowIndiVal()
{
   if(ShowValue)
   {
      if(gup[0]!=EMPTY_VALUE) lastV = gup[0];
      else lastV = gdna[0];
      displaystr = StringConcatenate("                         <------ ", lastV);
      if(ObjectFind("V_Label") < 0)
      {
         ObjectCreate("V_Label", OBJ_TEXT, 0, Time[0], lastV);
         ObjectSetText("V_Label", displaystr, FontSize, FontName, TextColor);
      }
      else if (ObjectFind("V_Label") == 0)
      {
         ObjectMove("V_Label", 0, Time[0], lastV);
         ObjectSetText("V_Label", displaystr, FontSize, FontName, TextColor);
      }
   }
}

