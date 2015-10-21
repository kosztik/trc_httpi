//+------------------------------------------------------------------+
//|                                              TradeCopyMaster.mq4 |
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
   2015.05.01
      A módosításom itt, hogy az eredeti egy fájlba írja a kereskedéseket, az
      itteni verzió pedig httpGET paranccsal egy php fájl hív meg egy szerveren
      ami egy adatbázisba írja be ezeket az adatokat.
      
      pl. string http_result = httpGET("url.php");

*/


#include <mq4-http.mqh>

#property copyright "Copyright © 2011, Syslog.eu, rel. 2012-01-04"
#property link      "http://syslog.eu"

extern string cutStringFromSym="";
extern string Prefix="";
extern string Suffix="";


int delay=1000;
int start,TickCount;
int Size=0,PrevSize=0;
int cnt,TotalCounter;
string cmt;
string nl="\n";
string httpstring="";

int OrdId[],PrevOrdId[];
string OrdSym[],PrevOrdSym[];
int OrdTyp[],PrevOrdTyp[];
double OrdLot[],PrevOrdLot[];
double OrdPrice[],PrevOrdPrice[];
double OrdSL[],PrevOrdSL[];
double OrdTP[],PrevOrdTP[];

string s[], http_result, http_result1;

// kliensbol athozott valtozok
double ForceLot=0.00;
double LotKoef=1.0;
string LotMapping="0.01=0.01,0.02=0.02";
double Balance=0;
double MicroLotBalance=0;



//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
//----
   //int handle=FileOpen("TradeCopy.csv",FILE_CSV|FILE_WRITE,",");
   //FileClose(handle);
   
   // kosztik: Amikor inditjuk az EA-t akkor be kell toltenie a szerverrol a tarolt kereskedeseket
   load_positions();
   
   Print ( PrevSize);
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//----
   
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start() {

  while(!IsStopped()) {
    start=GetTickCount();
    cmt=start+nl+"Counter: "+TotalCounter;
    get_positions();
    if(compare_positions()) {
         // Print ("Van mentes");
         save_positions(); // vagyis csak akkor ment, amikor változás van!
    } else {
         // Print ("nincs ment�s mert minde ua.");
    }
    Comment(cmt);
    TickCount=GetTickCount()-start;
    if(delay>TickCount)Sleep(delay-TickCount-2);
  }
  Alert("end, TradeCopy EA stopped");
  
  return(0);


//----

}


void get_positions() {
  Size=OrdersTotal();
  if (Size!= PrevSize) {
    ArrayResize(OrdId,Size);
    ArrayResize(OrdSym,Size);
    ArrayResize(OrdTyp,Size);
    ArrayResize(OrdLot,Size);
    ArrayResize(OrdPrice,Size);
    ArrayResize(OrdSL,Size);
    ArrayResize(OrdTP,Size);
  }

  for(int cnt=0;cnt<Size;cnt++) {
    OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
    OrdId[cnt]=OrderTicket();
    OrdSym[cnt]=OrderSymbol(); 
    OrdTyp[cnt]=OrderType();
    OrdLot[cnt]=OrderLots();
    OrdPrice[cnt]=OrderOpenPrice();
    OrdSL[cnt]=OrderStopLoss();
    OrdTP[cnt]=OrderTakeProfit();
    
    StringReplace(OrdSym[cnt], cutStringFromSym, "");
  }  
  cmt=cmt+nl+"Size: "+Size;  
}   
   
bool compare_positions() {
  if (PrevSize != Size)return(true);
  for(int i=0;i<Size;i++) {
    if (PrevOrdSL[i]!=OrdSL[i])return(true);
    if (PrevOrdTP[i]!=OrdTP[i])return(true);
    if (PrevOrdPrice[i]!=OrdPrice[i])return(true);
    if (PrevOrdId[i]!=OrdId[i])return(true);
    if (PrevOrdSym[i]!=OrdSym[i])return(true);
    if (PrevOrdPrice[i]!=OrdPrice[i])return(true);
    if (PrevOrdLot[i]!=OrdLot[i])return(true);
    if (PrevOrdTyp[i]!=OrdTyp[i])return(true);
  }    
  return(false);
}


void save_positions() {

  if (PrevSize != Size) {
    ArrayResize(PrevOrdId,Size);
    ArrayResize(PrevOrdSym,Size);
    ArrayResize(PrevOrdTyp,Size);
    ArrayResize(PrevOrdLot,Size);
    ArrayResize(PrevOrdPrice,Size);
    ArrayResize(PrevOrdSL,Size);
    ArrayResize(PrevOrdTP,Size);
    PrevSize=Size;
  }
  
  
  for(int i=0;i<Size;i++) {
    PrevOrdId[i]=OrdId[i];
    PrevOrdSym[i]=OrdSym[i];
    PrevOrdTyp[i]=OrdTyp[i];
    PrevOrdLot[i]=OrdLot[i];
    PrevOrdPrice[i]=OrdPrice[i];
    PrevOrdSL[i]=OrdSL[i];
    PrevOrdTP[i]=OrdTP[i];
  }

  // Size: hány aktív kereskedésünk van éppen. Ezt minden alkalommal újra és újra kiírja.
  
  int handle=FileOpen("TradeCopy.csv",FILE_CSV|FILE_WRITE,",");
  if(handle>0) {
    FileWrite(handle,TotalCounter);
    TotalCounter++;
    httpstring = "?";
    for(i=0;i<Size;i++) {
      FileWrite(handle,OrdId[i],OrdSym[i],OrdTyp[i],OrdLot[i],OrdPrice[i],OrdSL[i],OrdTP[i]);
      httpstring += "&size"+i+"="+Size+"&ordid"+i+"="+OrdId[i]+"&ordsym"+i+"="+OrdSym[i]+"&ordtyp"+i+"="+OrdTyp[i]+"&ordlot"+i+"="+OrdLot[i]+"&ordprice"+i+"="+OrdPrice[i]+"&ordsl"+i+"="+OrdSL[i]+"&ordtp"+i+"="+OrdTP[i]+"&";
    }
    FileClose(handle);
   
    // itt lehetne figyelni a visszatérést, amit az init.cgi ad esetleges hiba esetén
    //Print("http://alfa.triak.hu/trc/cgi-bin/init.cgi",httpstring);
   
      httpGET("http://mail.webkelet.hu:85/init.cgi"+httpstring);    
    
  }else Print("File open has failed, error: ",GetLastError());

  /*
      A fenti FileWrite íráskor össze kell állítanom egy hosszú stringet. Ebben benne van az összes trade.
      Ezt küldöm el, a httpGET hívással a szervernek. Ami lejegyzi a kereskedéseket mysql adatbázisba!
      
      A string:
      ?t=OrdId[i],OrdSym[i],OrdTyp[i],OrdLot[i],OrdPrice[i],OrdSL[i],OrdTP[i],kib,
         OrdId[i],OrdSym[i],OrdTyp[i],OrdLot[i],OrdPrice[i],OrdSL[i],OrdTP[i],kib,
         OrdId[i],OrdSym[i],OrdTyp[i],OrdLot[i],OrdPrice[i],OrdSL[i],OrdTP[i],kib,
   
      string http_result = httpGET("savetrade.php?t=OrdId[i],OrdSym[i],OrdTyp[i],OrdLot[i],OrdPrice[i],OrdSL[i],OrdTP[i]");
  */

}



   
//+------------------------------------------------------------------+
 
// Kosztik �ltal �trakott szubrutinok a TradeCopySlave-bol

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
  
  http_result1=StringSubstr(http_result, 0, StringLen(http_result)-1 );
  
  StringSplit(http_result1, StringGetCharacter("|",0), s);
  //Print ("http result: ", http_result);
  parse_s();
  
  return(0);
}

void parse_s() {
  
  if (PrevSize!=ArraySize(s)) {
    PrevSize=ArraySize(s);
    ArrayResize(PrevOrdId,PrevSize);
    ArrayResize(PrevOrdSym,PrevSize);
    ArrayResize(PrevOrdTyp,PrevSize);
    ArrayResize(PrevOrdLot,PrevSize);
    ArrayResize(PrevOrdPrice,PrevSize);
    ArrayResize(PrevOrdSL,PrevSize);
    ArrayResize(PrevOrdTP,PrevSize);
  }
  for(int i=0;i<ArraySize(s);i++) {
  
// get line length, starting position, find position of ",", calculate the length of the substring
    int Len=StringLen(s[i]);
    int start=0;
    int end=StringFind(s[i],",",start);
    int length=end-start;
// get Id
    PrevOrdId[i]=StrToInteger(StringSubstr(s[i],start,length));

    start=end+1;
    end=StringFind(s[i],",",start);
    length=end-start;
    PrevOrdSym[i]=Prefix+StringSubstr(s[i],start,length)+Suffix;
   
    start=end+1;
    end=StringFind(s[i],",",start);
    length=end-start;
    PrevOrdTyp[i]=StrToInteger(StringSubstr(s[i],start,length));

    start=end+1;
    end=StringFind(s[i],",",start);
    length=end-start;
    PrevOrdLot[i]=LotVol(StrToDouble(StringSubstr(s[i],start,length)),PrevOrdSym[i]);

    start=end+1;
    end=StringFind(s[i],",",start);
    length=end-start;
    PrevOrdPrice[i]=NormalizeDouble(StrToDouble(StringSubstr(s[i],start,length)),digits(PrevOrdSym[i]));

    start=end+1;
    end=StringFind(s[i],",",start);
    length=end-start;
    PrevOrdSL[i]=NormalizeDouble(StrToDouble(StringSubstr(s[i],start,length)),digits(PrevOrdSym[i]));

    start=end+1;
    end=StringFind(s[i],",",start);
    length=end-start;
    PrevOrdTP[i]=NormalizeDouble(StrToDouble(StringSubstr(s[i],start,length)),digits(PrevOrdSym[i]));

  }
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
 
int digits(string symbol){return(MarketInfo(symbol,MODE_DIGITS));}
