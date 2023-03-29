//+------------------------------------------------------------------+
//|                              Strategy2_RSI_exit_Candle_Entry.mq5 |
//|                                                  Giorgos Varnava |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Giorgos Varnava"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

//declare variables
CTrade trade;
double rsiBuffer;
double rsi[];
int tikNum = 0;
MqlTradeRequest tempRequest;
MqlTradeResult tempResult;
bool activeTrade = false;
MqlDateTime currTimeGMT;
bool timeWindow = false;
double BuffZones[2];
ENUM_ORDER_TYPE currTradeType = NULL;
int numOfBars = 0;
double lastRSI = 0;
double latestRsiClose = 0;
ulong tempticket = 0;


//Non-Event Methods for expert

//Method to check wether we are in the time window allowed for placing orders
bool TimeCheck(){
   TimeGMT(currTimeGMT);
   if((currTimeGMT.hour >= 8 && currTimeGMT.hour < 12) || (currTimeGMT.hour >= 15 && currTimeGMT.hour < 17) || (currTimeGMT.hour >= 18 && currTimeGMT.hour < 21)){
      return true;
   }else{
      return false;
   }
}

//Create a function with which we determine the latest trend High of the last 20 candlesticks
double GetLatestHigh()
  {
   int numOfCandles = 40;
   double highs[];
   double latestTrendHigh = 0;
//we make the array size 20
   ArrayResize(highs, numOfCandles);

//we loop through last 20 candles and get their high value
   for(int i = 0; i< numOfCandles; i++)
     {
      highs[i] = iHigh(Symbol(),PERIOD_CURRENT,i);
     }

//we loop through 5 of the highs in each iteration and check if there is a trend high
//if multiple returns the latest
   for(int i = 2; i < numOfCandles - 2; i++)
     {
      if(highs[i-2] < highs[i-1] && highs[i-1] < highs[i] && highs[i] > highs[i+1] && highs[i+1] > highs[i+2])
        {
         latestTrendHigh = highs[i];
         break;
        }
     }

   return latestTrendHigh;
  }


//Create a function with which we determine the latest trend low of the last 20 candlesticks
double GetLatestLow()
  {
   int numOfCandles = 40;
   double lows[];
   double latestTrendLow = 0;
//we make the array size 20
   ArrayResize(lows, numOfCandles);

//we loop through last 20 candles and get their high value
   for(int i = 0; i< numOfCandles; i++)
     {
      lows[i] = iLow(Symbol(),PERIOD_CURRENT,i);
     }

//we loop through 5 of the highs in each iteration and check if there is a trend high
//if multiple returns the latest
   for(int i = 2; i < numOfCandles - 2; i++)
     {
      if(lows[i-2] > lows[i-1] && lows[i-1] > lows[i] && lows[i] < lows[i+1] && lows[i+1] < lows[i+2])
        {
         latestTrendLow = lows[i];
         break;
        }
     }

   return latestTrendLow;
  }

//Method to check if we have an entry opportunity
//Opportunity is an engolfing candlestick formation in the last 2 candlesticks
int CandleEntryCheck(){
   int ret = 0;
   int numOfCandles = 2;
   double bodies[];
   ArrayResize(bodies, numOfCandles);
   //oldest candle
   int C1direction = 0;
   //newest candle
   int C2direction = 0;
   
   //check direction of candle 1
   if(iOpen(_Symbol, PERIOD_CURRENT, 2) < iClose(_Symbol,PERIOD_CURRENT,2)){ 
      //direction = 1 means bullish
      C1direction = 1;
   }else{
      //direction = 2 means bearish
      C1direction = 2;
   }
   
   //check direction of candle 2
   if(iOpen(_Symbol, PERIOD_CURRENT, 1) < iClose(_Symbol,PERIOD_CURRENT,1)){ 
      //direction = 1 means bullish
      C2direction = 1;
   }else{
      //direction = 2 means bearish
      C2direction = 2;
   } 
   
   //calculate 2 previous candle body sizes
   for(int i = 1; i <= numOfCandles; i++){
      bodies[i-1] = MathAbs(iHigh(_Symbol, PERIOD_CURRENT, i) - iLow(_Symbol, PERIOD_CURRENT, i));
   }
   
   //for C1 being bearish
   if(C1direction == 2){
      if(C2direction == 1 && bodies[0] > bodies[1] && iClose(_Symbol,PERIOD_CURRENT,1) > iOpen(_Symbol,PERIOD_CURRENT,2)){
         //then we have a trade entry opportunity, that is bullish
         //ret = 1 means bullish
         ret = 1;
         Print("ret1");
      }
   }else if(C1direction == 1){
      if(C2direction == 2 && bodies[0] > bodies[1] && iClose(_Symbol,PERIOD_CURRENT,1) < iOpen(_Symbol,PERIOD_CURRENT,2)){
            //then we have a trade entry opportunity, that is bearish
            //ret = 2 means bearish
            ret = 2;
            Print("ret2");
         }
   }
   return ret;
}   

//Method for bufferzone calculation
//here we calculate all of the buffer zones for both sell and buy orders
void calcBuffZones(){
   double spread =_Point*MathMax((((double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL))*1.4),((double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)));
   //SELL MINIMUM STOP LOSS
   BuffZones[0] = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + spread;
   //BUY MINIMUM STOP LOSS
   BuffZones[1] = SymbolInfoDouble(_Symbol, SYMBOL_BID) - spread;
}

//Method to check wether we have a new bar
bool isNewBar(){
   if(numOfBars < Bars(_Symbol, _Period)){
      numOfBars = Bars(_Symbol, _Period);
      return true;
   }else{
      return false;
   }
}

//EVENT METHODS
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   ArraySetAsSeries(rsi,true);
   //store iRSI indicator handler into rsiBuffer
   rsiBuffer = iRSI(_Symbol,_Period,3,PRICE_CLOSE);
   numOfBars = Bars(_Symbol,_Period);
   
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnTick(){
   //get latest RSI value
   CopyBuffer(rsiBuffer,0,0,1,rsi);

   if(isNewBar()){
      latestRsiClose = lastRSI;
   }else{
      //copy latest rsi value
      lastRSI = rsi[0];
   }
   
   //update activeTrades variable
   if(PositionsTotal() == 0){
      activeTrade = false;
   }
   //check if active order
   if(activeTrade == true){
      //if active order, check for exit RSI value
      if(currTradeType == ORDER_TYPE_BUY){
         if(latestRsiClose >= 70){
               
               if(!trade.PositionClose(_Symbol)){
                  Print("error closing order");
               }else{
               activeTrade = false;
               tempticket = 0;
               latestRsiClose = 50;
               }
                        
         }
      }else if(currTradeType == ORDER_TYPE_SELL){
            if(latestRsiClose <= 30){
               
               if(!trade.PositionClose(_Symbol)){
                  Print("error closing order");
               }else{
               activeTrade = false; 
               latestRsiClose = 50;
               }  
            }
         }
   }else{
      //if no active trade 
      //check if time to trade
      timeWindow = TimeCheck();
      //if time window is in the desired window
      if(timeWindow == true){
         //check if check if last 2 candles formed engolfing formation
         int check = CandleEntryCheck();
         //if there is an entry opportunity
         if(check != 0){
            //calculate buffers
            calcBuffZones();
            //get latest high and low
            double Low = GetLatestLow();
            double High = GetLatestHigh();
            //check if entry opportunity is bullish or bearish
            if(check == 1){
               //PREPARE BUY REQUEST
               tempRequest.type = ORDER_TYPE_BUY;
               tempRequest.action = TRADE_ACTION_DEAL;
               tempRequest.deviation = 20;
               tempRequest.symbol = _Symbol;
               tempRequest.volume = 0.25;
               tempRequest.price = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
               tempRequest.type_filling = ORDER_FILLING_FOK;
    
               //now to set stop loss and take profit we check current price
               //and compare to latest low
               /*if(Low < BuffZones[1] - 0.001){
                  tempRequest.sl = Low;
               }else{
                  tempRequest.sl = BuffZones[1] - 0.0012;
               } 
               */
               
               //place order
               if(!OrderSend(tempRequest,tempResult)){
                  PrintFormat("OrderSend error %d",GetLastError());  // if unable to send the request, output the error code
                  currTradeType = NULL;
               }
               currTradeType = ORDER_TYPE_BUY;
               activeTrade = true;
               //get ticket of current order
               tempticket = OrderGetTicket(0);
            }else if(check == 2){
            
                //PREPARE SELL REQUEST
                tempRequest.type = ORDER_TYPE_SELL;
                tempRequest.action = TRADE_ACTION_DEAL;
                tempRequest.deviation = 20;
                tempRequest.symbol = _Symbol;
                tempRequest.volume = 0.25;
                tempRequest.price    =SymbolInfoDouble(Symbol(),SYMBOL_BID);
                tempRequest.type_filling = ORDER_FILLING_FOK;

               //now to set stop loss we check current price
               //and compare to latest high
               /*if(High >BuffZones[0] + 0.001){
                 tempRequest.sl = High;
               }else{
                  tempRequest.sl = BuffZones[0] + 0.0012;
               }*/

               //place order
               if(!OrderSend(tempRequest,tempResult)){
                  PrintFormat("OrderSend error %d",GetLastError());  // if unable to send the request, output the error code
                  currTradeType = NULL;
               }
               currTradeType = ORDER_TYPE_SELL;
               activeTrade = true;
               //get ticket of current order
               tempticket = OrderGetTicket(0);
            }
         }
      }
   }   
}
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---
   
  }
//+------------------------------------------------------------------+
