//+------------------------------------------------------------------+
//|                                            LatestHighLowTest.mq5 |
//|                                                  Giorgos Varnava |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+


//declare variables
double rsiBuffer;
double rsi[];
int tikNum = 0;
MqlTradeRequest request;
MqlTradeResult result;
bool activeTrade = false;
bool bullRsi = false;
bool bearRsi = false;
bool leftRsiZone = true;
MqlDateTime currTimeGMT;
bool timeWindow = false;
double BuffZones[4];
input float multiplier = 1;
input int SLpips = 20;
int TPpips = SLpips * multiplier;
double point = 0; // the minimum price change, will be calculate in each trade attempt


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

//Check if candle is larger/smaller than its 11 previous candles. Returns 1 for bullish, 2 for bearish and 0 for no entry
int candleEntryCheck()
  {
   int ret = 0;
   bool flagLarger = true;
   int numOfCandles = 13;
   double bodies[];
   double lows[];
   double highs[];
//rezise arrays to size 13
   ArrayResize(bodies, numOfCandles-1);
   ArrayResize(lows, numOfCandles);
   ArrayResize(highs, numOfCandles);
//get 12 previous lows and highs
   for(int i = 0; i < numOfCandles; i++)
     {
      lows[i] = iLow(Symbol(),PERIOD_CURRENT,i);
      highs[i] = iHigh(Symbol(),PERIOD_CURRENT,i);
     }
//calculate 12 previous candle body sizes
   for(int i = 1; i < numOfCandles; i++)
     {
      bodies[i-1] = MathAbs(highs[i] - lows[i]);
     }
//check if latest body is larger than 11 others
   for(int i = 1; i < numOfCandles-1; i++)
     {
      if(bodies[0] < bodies[i])
        {
         flagLarger = false;
        }
     }

//if candle is larger, check direction of the candle so that we return an entry sign
//direction 1 = bullish, 2 = bearish
   if(flagLarger == true)
     {
      if(iOpen(_Symbol,PERIOD_CURRENT,1) < iClose(_Symbol,PERIOD_CURRENT, 1))
        {
         ret = 1;
        }
      else
         if(iOpen(_Symbol,PERIOD_CURRENT,1) > iClose(_Symbol,PERIOD_CURRENT, 1))
           {
            ret = 2;
           }
     }

   return ret;
  }
  
  //here we calculate all of the buffer zones for both sell and buy orders
  void calcBuffZones(){
   double spread =_Point*MathMax((((double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL))*1.4),((double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)*1.4));
   //SELL MINIMUM STOP LOSS
   BuffZones[0] = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + spread;
   //SELL MINIMUM TAKE PROFIT
   BuffZones[1] = SymbolInfoDouble(_Symbol, SYMBOL_BID) - spread;
   //BUY MINIMUM STOP LOSS
   BuffZones[2] = SymbolInfoDouble(_Symbol, SYMBOL_BID) - spread;
   //BUY MINIMUM TAKE PROFIT
   BuffZones[3] = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + spread;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {

   ArraySetAsSeries(rsi,true);
   rsiBuffer = iRSI(_Symbol,_Period,14,PRICE_CLOSE);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   ZeroMemory(request);
   ZeroMemory(result);
   if(PositionsTotal() == 0){
      activeTrade = false;
   }
   
   timeWindow = TimeCheck();
   calcBuffZones();
   
   //get latest high and low
   double Low = GetLatestLow();
   double High = GetLatestHigh();
   
   //get rsi
   CopyBuffer(rsiBuffer,0,0,1,rsi);
   //if(rsi[0] <50.01 && rsi[0] > 50.01){
   //   leftRsiZone = true;
   //}
   if(rsi[0] > 60.00 ){
      bearRsi = true;
      bullRsi = false;
      leftRsiZone = false;
   }else if(rsi[0] <40.00 ){
      bullRsi = true;
      bullRsi = false;
      leftRsiZone = false;
   }
   
   //if we get an RSI indication, we do a candle check
   if(timeWindow == true && bullRsi == true && activeTrade == false){
      int candleCheck = candleEntryCheck();
      if(candleCheck == 1){
         //create order request
         request.type = ORDER_TYPE_BUY;
         request.action = TRADE_ACTION_DEAL;
         request.deviation = 20;
         request.symbol = _Symbol;
         request.volume = 0.25;
         request.price = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
         request.type_filling = ORDER_FILLING_FOK;
         
         //now to set stop loss and take profit we check current price
         //and compare to latest hign and low
         
         if(High > BuffZones[3] + (SLpips/1.5 * point)){
            request.tp = High;
         }else{
            point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            request.tp = BuffZones[3] + (TPpips * point);
         }
         
         if(Low < BuffZones[2] - (SLpips/2 * point)){
            request.sl = Low;
         }else{
            point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            request.sl = BuffZones[2] - (SLpips * point);
         }
         
         bullRsi = false;
                  
         if(request.tp <=0 || request.sl <= 0){
            log("sl or tp error");
         }else{
            //place order
            if(!OrderSend(request,result)){
               PrintFormat("OrderSend error %d",GetLastError());} // if unable to send the request, output the error code
            //--- information about the operation
         }
         
         activeTrade = true;
         }
         
  
   }else if(timeWindow == true && bearRsi == true && activeTrade == false){
         //place order
      int candleCheck = candleEntryCheck();
      if(candleCheck == 2){
         //create order request
         request.type = ORDER_TYPE_SELL;
         request.action = TRADE_ACTION_DEAL;
         request.deviation = 20;
         request.symbol = _Symbol;
         request.volume = 0.25;
         request.price    =SymbolInfoDouble(Symbol(),SYMBOL_BID);
         request.type_filling = ORDER_FILLING_FOK;
         
         //now to set stop loss and take profit we check current price
         //and compare to latest high and low
         
         if(Low < BuffZones[1] - (SLpips/1.5 * point)){
            request.tp = Low;
         }else{
            point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            request.tp = BuffZones[1] - (TPpips * point);
         }
         
         if(High >BuffZones[0] + (SLpips/2 * point)){
           request.sl = High;
         }else{
            point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            request.sl = BuffZones[0] + (SLpips * point);
         }

         bearRsi = false;
         
         if(request.tp <=0 || request.sl <= 0){
            log("sl or tp error");
         }else{
            //place order
            if(!OrderSend(request,result)){
               PrintFormat("OrderSend error %d",GetLastError());} // if unable to send the request, output the error code
            //--- information about the operation
         }
         
         
         activeTrade = true;
      }
   }
 }
