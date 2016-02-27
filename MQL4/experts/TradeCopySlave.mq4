//+------------------------------------------------------------------+
//|                                               TradeCopySlave.mq4 |
//|                                                                  |
//| Copyright (c) 2011,2012 Vaclav Vobornik, Syslog.eu               |
//|                                                                  |
//| This program is free software: you can redistribute it and/or    |
//| modify it under the terms of the GNU General Public License      |
//| as published by the Free Software Foundation, either version 2   |
//| of the License, or (at your option) any later version.           |
//|                                                                  |
//| This program is distributed in the hope that it will be useful,  |
//| but WITHOUT ANY WARRANTY; without even the implied warranty of   |
//| MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the     |
//| GNU General Public License for more details.                     |
//|                                                                  |
//| You should have received a copy of the GNU General Public        |
//| License along with this program.                                 |
//| If not, see http://www.gnu.org/licenses/gpl-2.0                  |
//| See legal implications: http://gpl-violations.org/               |
//|                                                                  |
//|                                                 http://syslog.eu |
//+------------------------------------------------------------------+


/*
   2.01 verzio
   
   - alapertelmezett parameterek a lotkoef 1.0 es forcelot 0
   - lotmapping a 0.01 es 0.02 lotra 0.01 es 0.02
   
   Az elso azert kellett, mert a lotmapping csak akkor fur le, amikor 
   az eredeti lotmeret meg nincs modositva. A LotKoef erteke 1 es az 1-el
   valo szorzas modositatlanul hagyja a lotmeretet, igy lefuthat a lotmapping is
   ami szinten modositatlanul hagyja. Ez azert kellett mert szukseghelyzetbe mar 
   kavarodtam bele.
*/


/*
   2.00 verzió
   
   - sqlite-ba a fogadott kereskedések azonositoit berakja orderID
   - véletlenszerű stringet be kell állítani mt4ID, amit szintén tárol az
     adatbázisban. Ezzel a slave több mt4-ben is tudja kezelni az sqlite
     ban tárolt kereskedéseket!

*/


#include <sqlite.mqh>
#include <mq4-http.mqh>

#property copyright "Copyright © 2011, Syslog.eu, rel. 2012-05-15"
#property link      "http://syslog.eu"
// 2012-05-01 Prefix and Suffix added


extern string mt4ID="Enter a random string per mt4 please";
extern string filename="TradeCopy";
extern string S1="recalculate Lot by this koeficient:";
extern double LotKoef=1.0;
extern string S2="if set, force Lot to this value:";
extern double ForceLot=0.00;
extern string S3="is set, use this amount for every 0.01 Lot if higher than calculated above:";
extern double MicroLotBalance=0;
extern string S4="Lot mapping: source lot1=destination lot1,source lot2=destination lot2";
extern string S4a="If not given a pair, lot will recalculate with LotKoef and ForceLot";
extern string LotMapping="0.01=0.01,0.02=0.02";
extern string S4b="Progressive Lot on(1) or off(0)";
extern int ProgressiveLot=0;
extern int delay=1000;
extern double PipsTolerance=5;
extern int magic=20111219;
extern string Prefix="";
extern string Suffix="";
extern bool CopyDelayedTrades=false;
extern string comment0 = "########### these settings belongs to ProgressiveLot ############";
extern string comment1 = "1- micro, 2- mini, 3- normal";
extern string comment2 = "1 pip=$0.001, 1 pip=$0.01, 1 pip=$0.1";
extern int accountType = 2;
extern int riskInPercent = 5;
extern string comment3 = "For ex. xm micro accounts where 0.1L = 1 microL so the lotModifier 10";
extern int lotModifier = 0;
extern int SLinFPips = 400;

string db = "TradeCopy.db";
   
double Balance=0;
int start,TickCount;
int Size=0,RealSize=0,PrevSize=-1;
int cnt,TotalCounter=-1;
int mp=1;
string cmt;
string nl="\n";
double riskedMoney;

int OrdId[],RealOrdId[];
string OrdSym[],RealOrdSym[];
string RealOrdOrig[];
int OrdTyp[],RealOrdTyp[];
double OrdLot[],RealOrdLot[];
double OrdPrice[],RealOrdPrice[];
double OrdSL[],RealOrdSL[];
double OrdTP[],RealOrdTP[];
string s[], http_result, http_result1;
bool isHTTPGetOk, notradeHTTP ;
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() {
//----
  Comment("Waiting for a tick...");
  Print("Waiting for a tick...");
  if (IsStopped()) {
    Print("Is Stopped!!!!!!!!!!!");
  }
  if (!IsExpertEnabled()) {
    Print("Expert Is NOT Enabled!!!!!!!!!!!");
  }

  if (Digits == 5 || Digits == 3){    // Adjust for five (5) digit brokers.
    mp=10;
  }
  
  
  if (!sqlite_init()) {
        return INIT_FAILED;
  }
  
//----
  return(0);
}
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit() {

   sqlite_finalize();
  
//----
   
//----
   return(0);
  }
  
  
  
  
  bool do_check_table_exists (string db, string table)
{
    int res = sqlite_table_exists (db, table);

    if (res < 0) {
        Print ("Check for table existence failed with code " + res);
        return (false);
    }

    return (res > 0);
}

void do_exec (string db, string exp)
{
    int res = sqlite_exec (db, exp);
    
    if (res != 0)
        Print ("Expression '" + exp + "' failed with code " + res);
}



bool check_OrderID(unsigned int orderID) {
    int cols[1];
    bool isThere=false;
    int handle = sqlite_query (db, "select orderID from usedOrders WHERE orderID = '" + orderID + "' AND mt4ID LIKE '"+mt4ID+"' ", cols);

    //while (sqlite_next_row (handle) == 1) {
    //    for (int i = 0; i < cols[0]; i++)
    //        Print (sqlite_get_col (handle, i));
    //}
    
    //Print ("handle: " + sqlite_next_row (handle) );
    if (sqlite_next_row (handle) == 1) isThere=True;
    
    sqlite_free_query (handle);

    return isThere;
}
  
  
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
//int start() {

void OnTick() {
//----
  // Print("Got a tick...");
    
  if (!do_check_table_exists (db, "usedOrders")) {
       Print ("DB not exists, create schema");
       do_exec (db, "CREATE TABLE usedOrders (orderID unsigned big int, mt4ID string)");
    }
  load_positions();
  //while(!IsStopped()) {
    //if(!IsExpertEnabled()) break;
    
    
    
    if (isHTTPGetOk == true ) {
    
    start=GetTickCount();
 
    cmt="TickCount: "+start+nl+"Counter: "+TotalCounter;

    

    for(int i=0;i<Size;i++) {
      cmt=cmt+nl+" [ "+OrdId[i]+" ] [ "+OrdSym[i]+" ] [ "+VerbType(OrdTyp[i])+" ] [ "+OrdLot[i]+" ] [ "+OrdPrice[i]+" ] [ "+OrdSL[i]+" ] [ "+OrdTP[i]+" ]";
    }  
    
// Make sense to make changes only when the market is open and trading allowed
    if(IsTradeAllowed() && IsConnected()) {
      compare_positions();
      // do_exec (db, "INSERT INTO usedOrders (orderID) VALUES (1)");
    }

    Comment(cmt);
    TickCount=GetTickCount()-start;
    if(delay>TickCount)Sleep(delay-TickCount-2);
    
    
        
  //}
  //Alert("end, TradeCopy EA stopped");
  //Comment("");  
  }
  return(0);

}

void load_positions() {
  
   
   // Print (http_result);  
  
  /*
  int handle=FileOpen(filename+".csv",FILE_CSV|FILE_READ,";");
  if(handle>0) {

    string line=FileReadString(handle);
    if (TotalCounter == StrToInteger(line)) {
      FileClose(handle);
      return;
    }else{
      TotalCounter=StrToInteger(line);
    }
    int cnt=0;
    while(FileIsEnding(handle)==false) {
    cmt=cmt+nl+"DEBUG: reading file";
      if (ArraySize(s)<cnt+1) ArrayResize(s,cnt+1);
      s[cnt]=FileReadString(handle);
      cnt++;
    }
    FileClose(handle);
    ArrayResize(s,cnt);
    cmt=cmt+nl+"DEBUG: file end";
    
    parse_s();
  }else Print("Error opening file ",GetLastError());
  */
  
  
  // hibakezelés! ha nincs result!
  http_result = httpGET("http://mail.webkelet.hu:85/select.cgi");
  
  if (http_result == "false") {
   isHTTPGetOk = false;
   Print("HttpGet FALSE");
  } else {
   isHTTPGetOk = true;
  }
  
  if (http_result == " ") { 
   notradeHTTP = true; // Ilyenkor nincs keresked�s a szerveren
  } else {
   notradeHTTP = false; // Van keresked�s!
  }
  
  http_result1=StringSubstr(http_result, 0, StringLen(http_result)-1 );
  
  StringSplit(http_result1, StringGetCharacter("|",0), s);
  
  if (notradeHTTP == true) ArrayResize(s,0);
  //if (notradeHTTP==false) { // Csak akkor �rtelmezz�k a http eredm�ny�t, ha van keresked�s a szerveren!
   parse_s();
  //}
  
  return(0);
}
//+------------------------------------------------------------------+

void parse_s() {
  
  if (Size!=ArraySize(s)) {
    Size=ArraySize(s);
    ArrayResize(OrdId,Size);
    ArrayResize(OrdSym,Size);
    ArrayResize(OrdTyp,Size);
    ArrayResize(OrdLot,Size);
    ArrayResize(OrdPrice,Size);
    ArrayResize(OrdSL,Size);
    ArrayResize(OrdTP,Size);
  }
  for(int i=0;i<ArraySize(s);i++) {
  
// get line length, starting position, find position of ",", calculate the length of the substring
    int Len=StringLen(s[i]);
    int start=0;
    int end=StringFind(s[i],",",start);
    int length=end-start;
// get Id
    OrdId[i]=StrToInteger(StringSubstr(s[i],start,length));

    start=end+1;
    end=StringFind(s[i],",",start);
    length=end-start;
    OrdSym[i]=Prefix+StringSubstr(s[i],start,length)+Suffix;
   
    start=end+1;
    end=StringFind(s[i],",",start);
    length=end-start;
    OrdTyp[i]=StrToInteger(StringSubstr(s[i],start,length));

    start=end+1;
    end=StringFind(s[i],",",start);
    length=end-start;
    OrdLot[i]=LotVol(StrToDouble(StringSubstr(s[i],start,length)),OrdSym[i]);

    start=end+1;
    end=StringFind(s[i],",",start);
    length=end-start;
    OrdPrice[i]=NormalizeDouble(StrToDouble(StringSubstr(s[i],start,length)),digits(OrdSym[i]));

    start=end+1;
    end=StringFind(s[i],",",start);
    length=end-start;
    OrdSL[i]=NormalizeDouble(StrToDouble(StringSubstr(s[i],start,length)),digits(OrdSym[i]));

    start=end+1;
    end=StringFind(s[i],",",start);
    length=end-start;
    OrdTP[i]=NormalizeDouble(StrToDouble(StringSubstr(s[i],start,length)),digits(OrdSym[i]));

  }
}


double LotCalculate() {
   int ratio;
   double calculatedLot;
   // kiszamolom a equity risInPercent százalékát
   riskedMoney = (AccountEquity() * riskInPercent) / 100;
   
   switch ( accountType )                           // Operator header 
      {                                          // Opening brace
      case 1: ratio = 100; break;                   // One of the 'case' variations 
      case 2: ratio = 10;  break;                  // One of the 'case' variations 
      case 3: ratio = 1;   break;
      //[default: Operators]                        // Variation without any parameter
      }   
      
   calculatedLot = (0.1*riskedMoney) /(SLinFPips/ratio) ;
   if (lotModifier>0) calculatedLot = calculatedLot * lotModifier;
   
  return( NormalizeDouble(calculatedLot, 2) );    
}

double LotVol(double lot,string symbol) {



  ushort u_sep1, u_sep2;
  string sep1=",";
  string sep2="=";
  u_sep1 = StringGetCharacter(sep1,0);
  u_sep2 = StringGetCharacter(sep2,0);
  string ArrayLotMap1[], ArrayLotMap2[];

  if (ForceLot > 0) {
    lot=ForceLot;
  }else{
    lot=lot*LotKoef;
  }
  
  // LotMapping alapján újrakalkulálom a lot értékeket
  // Ha azonban itt nincs egyező pár akkor érintetlen marad
  // Az alap string amúgy is értintetlenül hagyja a lot -ot
  if (StringLen(LotMapping)>2) {
      int LotMapString1Width =StringSplit(LotMapping, u_sep1, ArrayLotMap1);
    
      for (int i=0;i< LotMapString1Width;i++) {
   
         int LotMapString2Width =StringSplit(ArrayLotMap1[i], u_sep2, ArrayLotMap2);
   
         // ha a map pár első eleme egyenlo a paraméterként adott lottal, akkor a második eleme szerint alakul a lot!
         if (lot == (double)ArrayLotMap2[0]) lot=(double)ArrayLotMap2[1];
   
      }

  }
  
  if (ProgressiveLot > 0) {
      lot= LotCalculate();
  }



  if (Balance<AccountBalance()) Balance=AccountBalance();
  
  if (MicroLotBalance > 0) {
    if (MathFloor(Balance/MicroLotBalance)/100 > lot) {
      lot=MathFloor(Balance/MicroLotBalance)/100;
    }
  }
//  Print("Calculated lot size: ",lot);
  // Print ("A következő lot méretet használom: "+lot);
  return(NormalizeDouble(lot,DigitsMinLot(symbol)));
}  
 
 

string VerbType (int type) {

  switch(type) {
    case 0:
      return ("BUY");
      break;
    case 1:
      return ("SELL");
      break;
    case 2:
      return ("BUY LIMIT");
      break;
    case 3:
      return ("SELL LIMIT");
      break;
    case 4:
      return ("BUY STOP");
      break;
    case 5:
      return ("SELL STOP");
      break;
  }
}


  
  
int DigitsMinLot(string symbol) {
   double ml=MarketInfo(symbol,MODE_MINLOT);
//--- 1/x of lot step
   double Dig=0;
   if(ml!=0)Dig=1.0/ml;
//--- conversion of 1/x to digits
   double res=0;
   if(Dig>1)res=1;
   if(Dig>10)res=2;
   if(Dig>100)res=3;
   if(Dig>1000)res=4;
   return(res);
}


void compare_positions() {
// load real positions and compare them with master ones
  real_positions();
  
  int x[];
  ArrayResize(x,RealSize);
  if (RealSize>0)ArrayInitialize(x,0);
//  cmt=cmt+nl+"RealSize: "+RealSize;

//Master to Real comparations
  for (int i=0;i<Size;i++) {       // for all master orders
    bool found=false;
    for (int j=0;j<RealSize;j++) { // find the right real order
     
      if (DoubleToStr(OrdId[i],0)==RealOrdOrig[j]) {
        
        //compare values
        found=true;
        x[j]=1;

// if not market order, compare open prices - later 
        //compare volumes - TODO later
        //compare open price when delayed order
        // Print (OrdTyp[i],">1", "&&", OrdPrice[i], "!=", RealOrdPrice[j]);
        if (OrdTyp[i]>1 && OrdPrice[i] != RealOrdPrice[j]) {
          OrderSelect(RealOrdId[j],SELECT_BY_TICKET);
          OrderModify(OrderTicket(),OrdPrice[i],OrderStopLoss(),OrderTakeProfit(),0);
        }
        //compare SL,TP
        
        //Print (OrdTP[i],"!=",RealOrdTP[j]," || ",OrdSL[i],"!=",RealOrdSL[j]);
        if (OrdTP[i]!=RealOrdTP[j] || OrdSL[i]!=RealOrdSL[j]) {
          
          OrderSelect(RealOrdId[j],SELECT_BY_TICKET);
          OrderModify(OrderTicket(),OrderOpenPrice(),OrdSL[i],OrdTP[i],0);
        }
      }
    }
    if (!found) {
      //no position open with this ID, need to open now      
      
      int result;
      if (OrdTyp[i]<2) {
// ------ market order (check Price and OpenPrice)
        double Price=MarketPrice(i);
 
// PipsTolerance for Price:
        if ((OrdTyp[i]==OP_BUY  && Price<OrdPrice[i]+PipsTolerance*mp*Point ) ||
           (OrdTyp[i]==OP_SELL && Price>OrdPrice[i]-PipsTolerance*mp*Point )) {
  
          
          result=OrderSend(OrdSym[i],OrdTyp[i],OrdLot[i],Price,5,0,0,DoubleToStr(OrdId[i],0),magic,0);
            
          if (result>0) OrderModify(result,OrderOpenPrice(),OrdSL[i],OrdTP[i],0);
          else Print ("Open ",OrdSym[i]," failed: ",GetLastError());
        }else Print ("Price out of tolerance ",DoubleToStr(OrdId[i],0),": ",OrdPrice[i],"/",Price);
      }else{
// ------ waiting order:
        if (CopyDelayedTrades) result=OrderSend(OrdSym[i],OrdTyp[i],OrdLot[i],OrdPrice[i],0,OrdSL[i],OrdTP[i],DoubleToStr(OrdId[i],0),magic,0);
      }
    
   
    
    
    }
  }
  for (j=0;j<RealSize;j++) {
//    cmt=cmt+nl+"checking "+j+" <> "+x[j];
    if (x[j]!=1) { //no master order, close the ticket
//      Price=MarketPrice(RealOrdSym[j],"close");
//      OrderClose(RealOrdId[j],RealOrdLot[j],Price,5,CLR_NONE);
      if (RealOrdTyp[j]<2) {
        Price=MarketPrice(j,"close");
        result=OrderClose(RealOrdId[j],RealOrdLot[j],Price,5,CLR_NONE);
        if (result<1) Print ("Close ",RealOrdId[j]," / ",RealOrdLot[j]," / ",Price," failed: ",GetLastError());
        if (Balance<AccountBalance()) Balance=AccountBalance();
      }else{
        OrderDelete(RealOrdId[j],CLR_NONE);
      }
    }
  }
}  

double MarketPrice(int i ,string typ="open") {
  RefreshRates();
  if (typ=="open") {
    if (OrdTyp[i]==0) {
      Print("Getting Ask open price for buy position...");
      return(NormalizeDouble(MarketInfo(OrdSym[i],MODE_ASK),digits(OrdSym[i])));
    }else{
      Print("Getting Bid open price for sell position...");
      return(NormalizeDouble(MarketInfo(OrdSym[i],MODE_BID),digits(OrdSym[i])));
    }
  }else {
//close:
    if (RealOrdTyp[i]==0) {
      Print("Getting Bid close price for buy position...");
      return(NormalizeDouble(MarketInfo(RealOrdSym[i],MODE_BID),digits(RealOrdSym[i])));
    }else{
      Print("Getting Ask close price for sell position...");
      return(NormalizeDouble(MarketInfo(RealOrdSym[i],MODE_ASK),digits(RealOrdSym[i])));
    }
  }
}

void real_positions() {

  int i=0;
  for(int cnt=0;cnt<OrdersTotal();cnt++) {
    OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
    if (OrderMagicNumber()==magic || ! magic) {
      if (RealSize<i+1)RealResize(i+1);    
      RealOrdId[i]=OrderTicket();
      RealOrdSym[i]=OrderSymbol();
      RealOrdTyp[i]=OrderType();
      RealOrdLot[i]=OrderLots();
      RealOrdPrice[i]=OrderOpenPrice();
      RealOrdSL[i]=OrderStopLoss();
      RealOrdTP[i]=OrderTakeProfit();
      RealOrdOrig[i]=OrderComment();
      i++;
    }
  }
  RealResize(i);
}   

void RealResize(int tmpsize) {

  if (RealSize != tmpsize) {
    RealSize = tmpsize;
    ArrayResize(RealOrdId,RealSize);
    ArrayResize(RealOrdSym,RealSize);
    ArrayResize(RealOrdTyp,RealSize);
    ArrayResize(RealOrdLot,RealSize);
    ArrayResize(RealOrdPrice,RealSize);
    ArrayResize(RealOrdSL,RealSize);
    ArrayResize(RealOrdTP,RealSize);
    ArrayResize(RealOrdOrig,RealSize);
  }

}

// To be used later:
//--- digits on the symbol
int digits(string symbol){return(MarketInfo(symbol,MODE_DIGITS));}
//--- point size
double point(string symbol){return(MarketInfo(symbol,MODE_POINT));}
//--- ask price
double ask(string symbol){return(MarketInfo(symbol,MODE_ASK));}
//--- bid price
double bid(string symbol){return(MarketInfo(symbol,MODE_BID));}
//--- spread
int spred(string symbol){return(MarketInfo(symbol,MODE_SPREAD));}
//--- stop level
int stlevel(string symbol){return(MarketInfo(symbol,MODE_STOPLEVEL));}
//--- max lot
double maxlot(string symbol){return(MarketInfo(symbol,MODE_MAXLOT));}
//--- min lot
double minlot(string symbol){return(MarketInfo(symbol,MODE_MINLOT));}


