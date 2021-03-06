//+------------------------------------------------------------------+
//|                            Martin 1(barabashkakvn's edition).mq5 |
//|                              Copyright © 2017, Vladimir Karputov |
//|                                           http://wmua.ru/slesar/ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2017, Vladimir Karputov"
#property link      "http://wmua.ru/slesar/"
#property version   "1.000"
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>  
#include <Trade\AccountInfo.mqh>
CPositionInfo  m_position;                   // trade position object
CTrade         m_trade;                      // trading object
CSymbolInfo    m_symbol;                     // symbol info object
CAccountInfo   m_account;                    // account info wrapper
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum trading_mode_enum
  {
   MODE_00=0,     // trade TP1 + TP2 + TP3
   MODE_01=1,     // trade TP1 + TP2
   MODE_02=2,     // trade TP1 + TP3
   MODE_03=3,     // trade TP2 + TP3
   MODE_04=4,     // trade TP1
   MODE_05=5,     // trade TP2
   MODE_06=6,     // trade TP3
   MODE_07=7,// trailing stop -like
  };
input trading_mode_enum input_trading_mode=MODE_00;

//--- input parameters
input double input_tp1_lot_size = 0.03; //lot size for tp1
input double input_tp2_lot_size = 0.02; //lot size for tp2
input double input_tp3_lot_size = 0.01; //lot size for tp3

input bool input_move_sl_to_open_price_when_arrive_tp1 = false; //move TP2' sl price to open price when price arrive tp1(TODO)
input bool input_move_sl_to_open_price_when_arrive_tp2 = false; //move TP3' sl price to open price when price arrive tp2(TODO)
input bool input_move_sl_to_tp1_when_arrive_tp2=false; //move TP3' sl price to tp1 when price arrive tp2(TODO)

input bool input_add_lot_size_when_arrive_tp1 = false; //Add lot size to TP2 when price arrive tp1(TODO)
input bool input_add_lot_size_when_arrive_tp2 = false; //Add lot size to TP3 when price arrive tp1(TODO)

input ulong input_magic_tp1=111111111;         // magic number tp1
input ulong input_magic_tp2=222222222;         // magic number tp2
input ulong input_magic_tp3=333333333;         // magic number tp3

input double               InpLots=0.01;               // Lots
                                                       //input ushort               InpStopLoss                = 40;                // Stop Loss (in pips)
//input ushort               InpTakeProfit              = 100;               // Take Profit (in pips)
input bool debug_mode=false; //debug mode

//---
ulong                      m_slippage=30;                                  // slippage

double                     ExtLot=0;
double                     ExtStopLoss=0;
double                     ExtTakeProfit=0;
double                     m_last_price=0.0;
int count=0;

ENUM_ACCOUNT_MARGIN_MODE   m_margin_mode;
double                     m_adjusted_point;                               // point value adjusted for 3 or 5 points

string cookie=NULL,headers;
char   post[],web_request_result_char_array[];
string url="http://www.raylilium.com/cat-hand-trade/get.php";
string web_request_result_string_array[];
bool is_done=false;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   if(!IsHedging())
     {
      Print("Hedging only!");
      return(INIT_FAILED);
     }
//---
   if(!m_symbol.Name(Symbol())) // sets symbol name
      return(INIT_FAILED);

   RefreshRates();

   string err_text="";
   if(!CheckVolumeValue(InpLots,err_text))
     {
      Print(err_text);
      return(INIT_PARAMETERS_INCORRECT);
     }
//---
//m_trade.SetExpertMagicNumber(input_magic_buy_test);
//---
   if(IsFillingTypeAllowed(SYMBOL_FILLING_FOK))
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if(IsFillingTypeAllowed(SYMBOL_FILLING_IOC))
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      m_trade.SetTypeFilling(ORDER_FILLING_RETURN);
//---
   m_trade.SetDeviationInPoints(m_slippage);
//--- tuning for 3 or 5 digits
   int digits_adjust=1;
   if(m_symbol.Digits()==3 || m_symbol.Digits()==5)
      digits_adjust=10;
   m_adjusted_point=m_symbol.Point()*digits_adjust;

//ExtStopLoss=InpStopLoss*m_adjusted_point;
//ExtTakeProfit=InpTakeProfit*m_adjusted_point;
//---

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

   if(isNewBar(PERIOD_M1))
     {

      int res=WebRequest("GET",url,cookie,NULL,500,post,0,web_request_result_char_array,headers);

      if(res==-1)
        {
         Print("Error in WebRequest. Error code  =",GetLastError());
         //--- Perhaps the URL is not listed, display a message about the necessity to add the address 
         MessageBox("Add the address '"+url+"' to the list of allowed URLs on tab 'Expert Advisors'","Error",MB_ICONINFORMATION);
        }
      else
        {
         if(res==200)
           {
            int k=StringSplit(CharArrayToString(web_request_result_char_array),StringGetCharacter("|",0),web_request_result_string_array);
            if(k>0 && ArraySize(web_request_result_string_array)>1)
              {

               //input_trading_mode=MODE_00

               string symbol=web_request_result_string_array[1];
               double entry_price1 = web_request_result_string_array[2];
               double entry_price2 = web_request_result_string_array[2];
               double entry_price3 = web_request_result_string_array[2];
               double sl1 = web_request_result_string_array[2];
               double sl2 = web_request_result_string_array[2];
               double sl3 = web_request_result_string_array[2];
               double tp1 = web_request_result_string_array[3];
               double tp2 = web_request_result_string_array[4];
               double tp3 = web_request_result_string_array[5];
               
               if(input_trading_mode=MODE_01)
               {
                  tp3 = 0;
               }
               if(input_trading_mode=MODE_02)
               {
                  tp2 = 0;
               }
               if(input_trading_mode=MODE_03)
               {
                  tp1 = 0;
               }
               if(input_trading_mode=MODE_04)
               {
                  tp2 = 0;
                  tp3 = 0;
               }
               if(input_trading_mode=MODE_05)
               {
                  tp1 = 0;
                  tp3 = 0;
               }
               if(input_trading_mode=MODE_06)
               {
                  tp1 = 0;
                  tp2 = 0;
               }
               if(input_trading_mode=MODE_07)
               {
                  //tp3 = 0;
                  sl3 = entry_price2;
                  entry_price3 = tp2;
                  
                  sl2 = entry_price1;
                  entry_price2 = tp1;
               }
               


               if(web_request_result_string_array[0]=="Buy")
                 {

                  if(tp1>0)
                    {
                     OpenBuyLimit(symbol,input_magic_tp1,input_tp1_lot_size,entry_price1,sl1,tp1);
                     OpenBuyStop(symbol,input_magic_tp1,input_tp1_lot_size,entry_price1,sl1,tp1);
                    }
                  if(tp2>0)
                    {
                     OpenBuyLimit(symbol,input_magic_tp2,input_tp2_lot_size,entry_price2,sl2,tp2);
                     OpenBuyStop(symbol,input_magic_tp2,input_tp2_lot_size,entry_price2,sl2,tp2);
                    }
                  if(tp3>0)
                    {
                     OpenBuyLimit(symbol,input_magic_tp3,input_tp3_lot_size,entry_price3,sl3,tp3);
                     OpenBuyStop(symbol,input_magic_tp3,input_tp3_lot_size,entry_price3,sl3,tp3);
                    }

                    } else {

                  if(tp1>0)
                    {
                     OpenSellLimit(symbol,input_magic_tp1,input_tp1_lot_size,entry_price1,sl1,tp1);
                     OpenSellStop(symbol,input_magic_tp1,input_tp1_lot_size,entry_price1,sl1,tp1);
                    }
                  if(tp2>0)
                    {
                     OpenSellLimit(symbol,input_magic_tp2,input_tp2_lot_size,entry_price2,sl2,tp2);
                     OpenSellStop(symbol,input_magic_tp2,input_tp2_lot_size,entry_price2,sl2,tp2);
                    }
                  if(tp3>0)
                    {
                     OpenSellLimit(symbol,input_magic_tp3,input_tp3_lot_size,entry_price3,sl3,tp3);
                     OpenSellStop(symbol,input_magic_tp3,input_tp3_lot_size,entry_price3,sl3,tp3);
                    }

                 }
/*
               if(web_request_result_string_array[0]=="Buy"){
                  
                  //bool OpenBuyLimit(string symbol , ulong magic_num,double lot,double price,double sl=0.0,double tp=0.0)
  
                  OpenBuyLimit(web_request_result_string_array[1], input_magic_tp1, input_tp1_lot_size ,web_request_result_string_array[2],web_request_result_string_array[6],web_request_result_string_array[3]);
                  OpenBuyLimit(web_request_result_string_array[1], input_magic_tp2, input_tp2_lot_size ,web_request_result_string_array[2],web_request_result_string_array[6],web_request_result_string_array[4]);
                  OpenBuyLimit(web_request_result_string_array[1], input_magic_tp3, input_tp3_lot_size ,web_request_result_string_array[2],web_request_result_string_array[6],web_request_result_string_array[5]);
                  
                  OpenBuyStop(web_request_result_string_array[1], input_magic_tp1, input_tp1_lot_size ,web_request_result_string_array[2],web_request_result_string_array[6],web_request_result_string_array[3]);
                  OpenBuyStop(web_request_result_string_array[1], input_magic_tp2, input_tp2_lot_size ,web_request_result_string_array[2],web_request_result_string_array[6],web_request_result_string_array[4]);
                  OpenBuyStop(web_request_result_string_array[1], input_magic_tp3, input_tp3_lot_size ,web_request_result_string_array[2],web_request_result_string_array[6],web_request_result_string_array[5]);
                  
               } else {
               
                  OpenSellLimit(web_request_result_string_array[1], input_magic_tp1, input_tp1_lot_size ,web_request_result_string_array[2],web_request_result_string_array[6],web_request_result_string_array[3]);
                  OpenSellLimit(web_request_result_string_array[1], input_magic_tp2, input_tp2_lot_size ,web_request_result_string_array[2],web_request_result_string_array[6],web_request_result_string_array[4]);
                  OpenSellLimit(web_request_result_string_array[1], input_magic_tp3, input_tp3_lot_size ,web_request_result_string_array[2],web_request_result_string_array[6],web_request_result_string_array[5]);
                  
                  OpenSellStop(web_request_result_string_array[1], input_magic_tp1, input_tp1_lot_size ,web_request_result_string_array[2],web_request_result_string_array[6],web_request_result_string_array[3]);
                  OpenSellStop(web_request_result_string_array[1], input_magic_tp2, input_tp2_lot_size ,web_request_result_string_array[2],web_request_result_string_array[6],web_request_result_string_array[4]);
                  OpenSellStop(web_request_result_string_array[1], input_magic_tp3, input_tp3_lot_size ,web_request_result_string_array[2],web_request_result_string_array[6],web_request_result_string_array[5]);
               
               }
               */

               SendNotification("3 pending orders were placed.");

              }

           }
         else
           {
            PrintFormat("Downloading '%s' failed, error code %d",url,res);
           }
        }

     }

   return;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsHedging(void)
  {
   return(m_account.MarginMode()==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
  }
//+------------------------------------------------------------------+
//| Refreshes the symbol quotes data                                 |
//+------------------------------------------------------------------+
bool RefreshRates(void)
  {
//--- refresh rates
   if(!m_symbol.RefreshRates())
     {
      Print("RefreshRates error");
      return(false);
     }
//--- protection against the return value of "zero"
   if(m_symbol.Ask()==0 || m_symbol.Bid()==0)
      return(false);
//---
   return(true);
  }
//+------------------------------------------------------------------+
//| Check the correctness of the order volume                        |
//+------------------------------------------------------------------+
bool CheckVolumeValue(double volume,string &error_description)
  {
//--- minimal allowed volume for trade operations
// double min_volume=m_symbol.LotsMin();
   double min_volume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   if(volume<min_volume)
     {
      error_description=StringFormat("Volume is less than the minimal allowed SYMBOL_VOLUME_MIN=%.2f",min_volume);
      return(false);
     }

//--- maximal allowed volume of trade operations
// double max_volume=m_symbol.LotsMax();
   double max_volume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
   if(volume>max_volume)
     {
      error_description=StringFormat("Volume is greater than the maximal allowed SYMBOL_VOLUME_MAX=%.2f",max_volume);
      return(false);
     }

//--- get minimal step of volume changing
// double volume_step=m_symbol.LotsStep();
   double volume_step=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);

   int ratio=(int)MathRound(volume/volume_step);
   if(MathAbs(ratio*volume_step-volume)>0.0000001)
     {
      error_description=StringFormat("Volume is not a multiple of the minimal step SYMBOL_VOLUME_STEP=%.2f, the closest correct volume is %.2f",
                                     volume_step,ratio*volume_step);
      return(false);
     }
   error_description="Correct volume value";
   return(true);
  }
//+------------------------------------------------------------------+ 
//| Checks if the specified filling mode is allowed                  | 
//+------------------------------------------------------------------+ 
bool IsFillingTypeAllowed(int fill_type)
  {
//--- Obtain the value of the property that describes allowed filling modes 
   int filling=m_symbol.TradeFillFlags();
//--- Return true, if mode fill_type is allowed 
   return((filling & fill_type)==fill_type);
  }
//+------------------------------------------------------------------+
//| Lot Check                                                        |
//+------------------------------------------------------------------+
double LotCheck(double lots)
  {
//--- calculate maximum volume
   double volume=NormalizeDouble(lots,2);
   double stepvol=m_symbol.LotsStep();
   if(stepvol>0.0)
      volume=stepvol*MathFloor(volume/stepvol);
//---
   double minvol=m_symbol.LotsMin();
   if(volume<minvol)
      volume=0.0;
//---
   double maxvol=m_symbol.LotsMax();
   if(volume>maxvol)
      volume=maxvol;
   return(volume);
  }
//+------------------------------------------------------------------+
//| Open Buy position                                                |
//+------------------------------------------------------------------+
void OpenBuy(ulong magic_num,double lot)
  {
   if(!RefreshRates())
      return;
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   m_trade.SetExpertMagicNumber(magic_num);
   double check_volume_lot=m_trade.CheckVolume(m_symbol.Name(),lot,m_symbol.Ask(),ORDER_TYPE_BUY);

   if(check_volume_lot!=0.0)
      if(check_volume_lot>=lot)
        {
         if(m_trade.Buy(lot,NULL,m_symbol.Ask()))
           {
            if(m_trade.ResultDeal()==0)
              {
               if(debug_mode) Print("#1 Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),", description of result: ",m_trade.ResultRetcodeDescription());
               PrintResult(m_trade,m_symbol);
              }
            else
              {
               if(debug_mode) Print("#2 Buy -> true. Result Retcode: ",m_trade.ResultRetcode(),", description of result: ",m_trade.ResultRetcodeDescription());
               PrintResult(m_trade,m_symbol);
              }
           }
         else
           {
            if(debug_mode) Print("#3 Buy -> false. Result Retcode: ",m_trade.ResultRetcode(),", description of result: ",m_trade.ResultRetcodeDescription());
            PrintResult(m_trade,m_symbol);
           }
        }
//---
  }
//+------------------------------------------------------------------+
//| Open Sell position                                               |
//+------------------------------------------------------------------+
bool OpenSell(ulong magic_num,double lot,double sl=0.0,double tp=0.0)
  {
   if(!RefreshRates())
      return false;
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   m_trade.SetExpertMagicNumber(magic_num);
   double check_volume_lot=m_trade.CheckVolume(m_symbol.Name(),lot,m_symbol.Bid(),ORDER_TYPE_SELL);

   if(check_volume_lot!=0.0)
      if(check_volume_lot>=lot)
        {
         if(m_trade.Sell(lot,NULL,m_symbol.Bid(),sl,tp,"OpenSell"))
           {
            if(m_trade.ResultDeal()==0)
              {
               if(debug_mode) Print("#1 Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),", description of result: ",m_trade.ResultRetcodeDescription());
               PrintResult(m_trade,m_symbol);
               return false;
              }
            else
              {
               if(debug_mode) Print("#2 Sell -> true. Result Retcode: ",m_trade.ResultRetcode(),", description of result: ",m_trade.ResultRetcodeDescription());
               PrintResult(m_trade,m_symbol);

               return true;
              }
           }
         else
           {
            if(debug_mode) Print("#3 Sell -> false. Result Retcode: ",m_trade.ResultRetcode(),", description of result: ",m_trade.ResultRetcodeDescription());
            PrintResult(m_trade,m_symbol);
            return false;
           }
        }
   return false;
//---
  }
//+------------------------------------------------------------------+
//| Open Buy Limit position                                               |
//+------------------------------------------------------------------+
bool OpenBuyLimit(string symbol,ulong magic_num,double lot,double price,double sl=0.0,double tp=0.0)
  {
   if(!RefreshRates())
      return false;
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   m_trade.SetExpertMagicNumber(magic_num);
   m_trade.SetTypeFillingBySymbol(symbol);
   double check_volume_lot=m_trade.CheckVolume(symbol,lot,price,ORDER_TYPE_SELL);

   if(check_volume_lot!=0.0)
      if(check_volume_lot>=lot)
        {
         if(m_trade.BuyLimit(lot,price,symbol,sl,tp,ORDER_TIME_GTC,0,""))
           {
            if(m_trade.ResultRetcode()!=TRADE_RETCODE_DONE)
              {
               return false;
              }
            else
              {
               return true;
              }
           }
         else
           {
            return false;
           }
        }

   return false;
//---
  }
//+------------------------------------------------------------------+
//| Open Buy Stop  position                                               |
//+------------------------------------------------------------------+
bool OpenBuyStop(string symbol,ulong magic_num,double lot,double price,double sl=0.0,double tp=0.0)
  {
   if(!RefreshRates())
      return false;
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   m_trade.SetExpertMagicNumber(magic_num);
   m_trade.SetTypeFillingBySymbol(symbol);
   double check_volume_lot=m_trade.CheckVolume(symbol,lot,price,ORDER_TYPE_SELL);

   if(check_volume_lot!=0.0)
      if(check_volume_lot>=lot)
        {
         if(m_trade.BuyStop(lot,price,symbol,sl,tp,ORDER_TIME_GTC,0,""))
           {
            if(m_trade.ResultRetcode()!=TRADE_RETCODE_DONE)
              {
               return false;
              }
            else
              {
               return true;
              }
           }
         else
           {
            return false;
           }
        }

   return false;
//---
  }
//+------------------------------------------------------------------+
//| Open Sell Limit position                                               |
//+------------------------------------------------------------------+
bool OpenSellLimit(string symbol,ulong magic_num,double lot,double price,double sl=0.0,double tp=0.0)
  {
   if(!RefreshRates())
      return false;
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   m_trade.SetExpertMagicNumber(magic_num);
   m_trade.SetTypeFillingBySymbol(symbol);
   double check_volume_lot=m_trade.CheckVolume(symbol,lot,price,ORDER_TYPE_SELL);

   if(check_volume_lot!=0.0)
      if(check_volume_lot>=lot)
        {
         if(m_trade.SellLimit(lot,price,symbol,sl,tp,ORDER_TIME_GTC,0,""))
           {
            if(m_trade.ResultRetcode()!=TRADE_RETCODE_DONE)
              {
               return false;
              }
            else
              {
               return true;
              }
           }
         else
           {
            return false;
           }
        }

   return false;
//---
  }
//+------------------------------------------------------------------+
//| Open Sell Stop position                                               |
//+------------------------------------------------------------------+
bool OpenSellStop(string symbol,ulong magic_num,double lot,double price,double sl=0.0,double tp=0.0)
  {
   if(!RefreshRates())
      return false;
//--- check volume before OrderSend to avoid "not enough money" error (CTrade)
   m_trade.SetExpertMagicNumber(magic_num);
   m_trade.SetTypeFillingBySymbol(symbol);
   double check_volume_lot=m_trade.CheckVolume(symbol,lot,price,ORDER_TYPE_SELL);

   if(check_volume_lot!=0.0)
      if(check_volume_lot>=lot)
        {
         if(m_trade.SellStop(lot,price,symbol,sl,tp,ORDER_TIME_GTC,0,""))
           {
            if(m_trade.ResultRetcode()!=TRADE_RETCODE_DONE)
              {
               return false;
              }
            else
              {
               return true;
              }
           }
         else
           {
            return false;
           }
        }

   return false;
//---
  }
//+------------------------------------------------------------------+
//| Print CTrade result                                              |
//+------------------------------------------------------------------+
void PrintResult(CTrade &trade,CSymbolInfo &symbol)
  {
   if(debug_mode)
     {
      Print("/* ");
      Print("Code of request result: "+IntegerToString(trade.ResultRetcode()));
      Print("code of request result: "+trade.ResultRetcodeDescription());
      Print("deal ticket: "+IntegerToString(trade.ResultDeal()));
      Print("order ticket: "+IntegerToString(trade.ResultOrder()));
      Print("volume of deal or order: "+DoubleToString(trade.ResultVolume(),2));
      Print("price, confirmed by broker: "+DoubleToString(trade.ResultPrice(),symbol.Digits()));
      Print("current bid price: "+DoubleToString(trade.ResultBid(),symbol.Digits()));
      Print("current ask price: "+DoubleToString(trade.ResultAsk(),symbol.Digits()));
      Print("broker comment: "+trade.ResultComment());
      Print("*/ ");
     }
//DebugBreak();
  }
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   double res=0.0;
   int losses=0.0;
//--- get transaction type as enumeration value 
   ENUM_TRADE_TRANSACTION_TYPE type=trans.type;
//--- if transaction is result of addition of the transaction in history
   if(type==TRADE_TRANSACTION_DEAL_ADD)
     {
      long     deal_ticket       =0;
      long     deal_order        =0;
      long     deal_time         =0;
      long     deal_time_msc     =0;
      long     deal_type         =-1;
      long     deal_entry        =-1;
      long     deal_magic        =0;
      long     deal_reason       =-1;
      long     deal_position_id  =0;
      double   deal_volume       =0.0;
      double   deal_price        =0.0;
      double   deal_commission   =0.0;
      double   deal_swap         =0.0;
      double   deal_profit       =0.0;
      string   deal_symbol       ="";
      string   deal_comment      ="";
      string   deal_external_id  ="";
      if(HistoryDealSelect(trans.deal))
        {
         deal_ticket       =HistoryDealGetInteger(trans.deal,DEAL_TICKET);
         deal_order        =HistoryDealGetInteger(trans.deal,DEAL_ORDER);
         deal_time         =HistoryDealGetInteger(trans.deal,DEAL_TIME);
         deal_time_msc     =HistoryDealGetInteger(trans.deal,DEAL_TIME_MSC);
         deal_type         =HistoryDealGetInteger(trans.deal,DEAL_TYPE);
         deal_entry        =HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
         deal_magic        =HistoryDealGetInteger(trans.deal,DEAL_MAGIC);
         deal_reason       =HistoryDealGetInteger(trans.deal,DEAL_REASON);
         deal_position_id  =HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);

         deal_volume       =HistoryDealGetDouble(trans.deal,DEAL_VOLUME);
         deal_price        =HistoryDealGetDouble(trans.deal,DEAL_PRICE);
         deal_commission   =HistoryDealGetDouble(trans.deal,DEAL_COMMISSION);
         deal_swap         =HistoryDealGetDouble(trans.deal,DEAL_SWAP);
         deal_profit       =HistoryDealGetDouble(trans.deal,DEAL_PROFIT);

         deal_symbol       =HistoryDealGetString(trans.deal,DEAL_SYMBOL);
         deal_comment      =HistoryDealGetString(trans.deal,DEAL_COMMENT);
         deal_external_id  =HistoryDealGetString(trans.deal,DEAL_EXTERNAL_ID);
        }
      else
         return;
      //if(deal_reason!=-1)
      //DebugBreak();
/*if(deal_symbol==m_symbol.Name() && deal_magic==m_magic_1)
         if(deal_entry==DEAL_ENTRY_IN)
            m_last_price=deal_price;*/
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Returns true if a new bar has appeared, overwise return false    |
//+------------------------------------------------------------------+
bool isNewBar(ENUM_TIMEFRAMES timeFrame)
  {
//----
   static datetime old_Times[21];// an array for old time values
   bool res=false;               // variable for the result
   int  i=0;                     // index of old_Times[] array
   datetime new_Time[1];         // time of a new bar
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   switch(timeFrame)
     {
      case PERIOD_M1:  i= 0; break;
      case PERIOD_M2:  i= 1; break;
      case PERIOD_M3:  i= 2; break;
      case PERIOD_M4:  i= 3; break;
      case PERIOD_M5:  i= 4; break;
      case PERIOD_M6:  i= 5; break;
      case PERIOD_M10: i= 6; break;
      case PERIOD_M12: i= 7; break;
      case PERIOD_M15: i= 8; break;
      case PERIOD_M20: i= 9; break;
      case PERIOD_M30: i=10; break;
      case PERIOD_H1:  i=11; break;
      case PERIOD_H2:  i=12; break;
      case PERIOD_H3:  i=13; break;
      case PERIOD_H4:  i=14; break;
      case PERIOD_H6:  i=15; break;
      case PERIOD_H8:  i=16; break;
      case PERIOD_H12: i=17; break;
      case PERIOD_D1:  i=18; break;
      case PERIOD_W1:  i=19; break;
      case PERIOD_MN1: i=20; break;
     }
// copying the last bar time to the element new_Time[0]
   int copied=CopyTime(_Symbol,timeFrame,0,1,new_Time);
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(copied>0) // ok, the data has been copied successfully
     {
      if(old_Times[i]!=new_Time[0]) // if old time isn't equal to new bar time
        {
         if(old_Times[i]!=0) res=true;    // if it isn't a first call, the new bar has appeared
         old_Times[i]=new_Time[0];        // saving bar time
        }
     }
//----
   return(res);
  }
//+------------------------------------------------------------------+
