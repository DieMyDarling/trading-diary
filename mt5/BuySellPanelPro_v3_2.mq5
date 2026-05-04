//+------------------------------------------------------------------+
//| Buy-Sell Panel PRO v3.2                                          |
//| Pending orders + manual price input + setup/trend info           |
//| No trailing logic, no mode label                                 |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

CTrade trade;

input double DefaultLotSize               = 0.10;
input double MaxSL_Dollars                = 11.0;
input double TakeProfitDollars            = 15.0;
input double BE_FixedOffsetDollars        = 1.5;
input double SplitTP1_Dollars             = 3.5;   // 30%
input double SplitTP2_Dollars             = 7.0;   // 30%
input double SplitTP3_Dollars             = 11.0;  // 20%
input double SplitTP4_Dollars             = 15.0;  // 20%
input double GroupSLMoveTriggerDollars    = 5.0;   // move passed from entry
input double GroupSLMoveOffsetDollars     = 1.0;   // SL to entry +/- offset
input bool   InpUseSplitMode              = true;  // start mode: split 30/30/20/20

input double AutoBE_TriggerToTPPercent    = 75.0; // trigger when X% of TP path passed
input double AutoBE_MoveToTPPercent       = 30.0; // move SL to X% of TP path from entry

//--- Levels
input bool   InpShowPivot                 = true;
input int    InpPivotType                 = 2; // 0 Classic, 1 Fibonacci, 2 Camarilla, 3 Woodie
input bool   InpShowPrevDayHL             = true;
input bool   InpShowAsianRange            = true;
input bool   InpShowSwingHL               = true;
input bool   InpShowTodayHL               = true;
input color  InpColorPivot                = clrDodgerBlue;
input color  InpColorPrevDay              = clrGoldenrod;
input color  InpColorAsian                = clrMediumPurple;
input color  InpColorSwing                = clrLimeGreen;
input color  InpColorToday                = clrOrange;
input int    InpLineWidth                 = 1;

const int UI_START_X           = 10;
const int UI_START_Y           = 30;
const int UI_BUTTON_WIDTH      = 120;
const int UI_BUTTON_HEIGHT     = 35;
const int UI_BUTTON_SPACING_X  = 20;
const int UI_BUTTON_SPACING_Y  = 10;
const int UI_TEXT_X            = 10;
const int UI_BLOCK_GAP_Y       = 34;

struct PivotLevels {
   double PP, R1, R2, R3, R4, S1, S2, S3, S4;
};

int      ATR_handle;
double   currentLotInput       = DefaultLotSize;
ulong    glPositionTicket      = 0;
double   glEntryPrice          = 0;
bool     autoBEApplied         = false;
double   glAsianHigh           = 0;
double   glAsianLow            = 0;
double   glAsianMid            = 0;
double   glPrevHigh            = 0;
double   glPrevLow             = 0;
double   glPrevClose           = 0;
double   glSwingHigh           = 0;
double   glSwingLow            = 0;
PivotLevels glPivot;
bool splitModeEnabled = true;

color clrText     = clrWhite;
color clrTrend    = clrLightGreen;
color clrBearish  = clrLightCoral;
color clrSoftBlue = C'135,206,250';

color MakeColor(int r, int g, int b) {
   return (color)(r | (g << 8) | (b << 16));
}

//================ UI HELPERS ================
void CreateButton(string name, string text, int x, int y, int width, color bgColor) {
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, UI_BUTTON_HEIGHT);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 12);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1000);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void CreateEdit(string name, int x, int y, int w, int h, string text) {
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 12);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, MakeColor(40, 40, 40));
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, MakeColor(100, 100, 100));
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1000);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
}

void CreateLabel(string name, int x, int y, string text, int fontSize = 11, color clr = clrWhite) {
   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);

   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1000);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void BringPanelControlsToFront() {
   string controls[] = {
      "lot_label", "lot_edit", "pending_price_label", "pending_price_edit",
      "BUY", "SELL", "BUY_LIMIT", "SELL_LIMIT", "BE", "REFRESH_LEVELS", "SPLIT_MODE"
   };
   for(int i = 0; i < ArraySize(controls); i++) {
      if(ObjectFind(0, controls[i]) >= 0) {
         ObjectSetInteger(0, controls[i], OBJPROP_ZORDER, 1000);
         ObjectSetInteger(0, controls[i], OBJPROP_BACK, false);
      }
   }
}

void UpdateSplitModeButton() {
   if(ObjectFind(0, "SPLIT_MODE") < 0) return;
   string txt = splitModeEnabled ? "SPLIT: ON" : "SPLIT: OFF";
   color bg = splitModeEnabled ? MakeColor(70, 150, 220) : MakeColor(90, 90, 90);
   ObjectSetString(0, "SPLIT_MODE", OBJPROP_TEXT, txt);
   ObjectSetInteger(0, "SPLIT_MODE", OBJPROP_BGCOLOR, bg);
}

void CreateOrUpdateLabel(string name, int x, int y, string text, int fontSize, color clr) {
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

int GetInfoBlockStartY() {
   if(ObjectFind(0, "REFRESH_LEVELS") >= 0) {
      int y = (int)ObjectGetInteger(0, "REFRESH_LEVELS", OBJPROP_YDISTANCE);
      int h = (int)ObjectGetInteger(0, "REFRESH_LEVELS", OBJPROP_YSIZE);
      return y + h + UI_BLOCK_GAP_Y;
   }
   if(ObjectFind(0, "BE") >= 0) {
      int y2 = (int)ObjectGetInteger(0, "BE", OBJPROP_YDISTANCE);
      int h2 = (int)ObjectGetInteger(0, "BE", OBJPROP_YSIZE);
      return y2 + h2 + UI_BLOCK_GAP_Y;
   }

   int controlsBottom = UI_START_Y + 35 + (UI_BUTTON_HEIGHT + UI_BUTTON_SPACING_Y) * 4;
   return controlsBottom + UI_BLOCK_GAP_Y;
}

int NextLineY(int currentY, int fontSize, int extraGap = 0) {
   int lineStep = MathMax(fontSize + 12, 24);
   return currentY + lineStep + extraGap;
}

void CleanupLegacyObjects() {
   string exactNames[] = {
      "BZ_RECT", "BZ_POC", "BZ_VAH", "BZ_VAL",
      "REFRESH_LEVELS", "AUTO_BUTTON",
      "mode_line", "divider_line",
      "liq_line", "liq_above_line", "liq_below_line",
      "range_line"
   };

   for(int i = 0; i < ArraySize(exactNames); i++) {
      if(ObjectFind(0, exactNames[i]) >= 0) ObjectDelete(0, exactNames[i]);
   }

   for(int i = ObjectsTotal(0) - 1; i >= 0; i--) {
      string name = ObjectName(0, i);
      if(StringFind(name, "GL_") == 0 || StringFind(name, "BZ_") == 0) {
         ObjectDelete(0, name);
      }
   }
}

//================ LEVELS ==================
bool GetPrevDayData(double &high, double &low, double &close) {
   high  = iHigh(_Symbol, PERIOD_D1, 1);
   low   = iLow(_Symbol, PERIOD_D1, 1);
   close = iClose(_Symbol, PERIOD_D1, 1);
   return !(high == 0 || low == 0);
}

PivotLevels CalcPivots(int type, double high, double low, double close) {
   PivotLevels p = {0,0,0,0,0,0,0,0,0};
   double range = high - low;
   if(range <= 0) return p;

   double open = iOpen(_Symbol, PERIOD_D1, 1);
   switch(type) {
      case 0: // Classic
         p.PP = (high + low + close) / 3.0;
         p.R1 = 2.0 * p.PP - low;
         p.S1 = 2.0 * p.PP - high;
         p.R2 = p.PP + range;
         p.S2 = p.PP - range;
         p.R3 = high + 2.0 * (p.PP - low);
         p.S3 = low - 2.0 * (high - p.PP);
         break;
      case 1: // Fibonacci
         p.PP = (high + low + close) / 3.0;
         p.R1 = p.PP + range * 0.382;
         p.R2 = p.PP + range * 0.618;
         p.R3 = p.PP + range;
         p.S1 = p.PP - range * 0.382;
         p.S2 = p.PP - range * 0.618;
         p.S3 = p.PP - range;
         break;
      case 2: // Camarilla
         p.R1 = close + range * 1.1 / 12.0;
         p.R2 = close + range * 1.1 / 6.0;
         p.R3 = close + range * 1.1 / 4.0;
         p.R4 = close + range * 1.1 / 2.0;
         p.S1 = close - range * 1.1 / 12.0;
         p.S2 = close - range * 1.1 / 6.0;
         p.S3 = close - range * 1.1 / 4.0;
         p.S4 = close - range * 1.1 / 2.0;
         p.PP = (p.R1 + p.S1) / 2.0;
         break;
      case 3: // Woodie
         p.PP = (high + low + open + open) / 4.0;
         p.R1 = 2.0 * p.PP - low;
         p.S1 = 2.0 * p.PP - high;
         p.R2 = p.PP + range;
         p.S2 = p.PP - range;
         break;
   }

   return p;
}

void GetAsianRange(double &high, double &low, double &mid) {
   high = 0; low = 0; mid = 0;
   MqlDateTime now;
   TimeCurrent(now);

   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   t.hour = 0; t.min = 0; t.sec = 0;
   datetime start = StructToTime(t);
   t.hour = 9;
   datetime end = StructToTime(t);

   if(now.hour < 9) { start -= 86400; end -= 86400; }

   int bars = Bars(_Symbol, PERIOD_M15, start, end);
   if(bars <= 0) return;

   high = iHigh(_Symbol, PERIOD_M15, iHighest(_Symbol, PERIOD_M15, MODE_HIGH, bars, 0));
   low  = iLow(_Symbol, PERIOD_M15, iLowest(_Symbol, PERIOD_M15, MODE_LOW, bars, 0));
   mid  = (high + low) / 2.0;
}

void GetSwingHL() {
   glSwingHigh = 0;
   glSwingLow = 1000000;
   for(int i = 1; i <= 10; i++) {
      double high = iHigh(_Symbol, PERIOD_H1, i);
      double low  = iLow(_Symbol, PERIOD_H1, i);
      if(high > glSwingHigh) glSwingHigh = high;
      if(low < glSwingLow) glSwingLow = low;
   }
}

void CreateLine(string name, double price, color clr, int width, string label = "") {
   if(price <= 0) return;

   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   } else {
      ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   }

   if(label != "") {
      string lbl = name + "_lbl";
      datetime labelTime = iTime(_Symbol, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * 3;
      if(ObjectFind(0, lbl) < 0) {
         ObjectCreate(0, lbl, OBJ_TEXT, 0, labelTime, price);
         ObjectSetString(0, lbl, OBJPROP_TEXT, label);
         ObjectSetInteger(0, lbl, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 9);
         ObjectSetInteger(0, lbl, OBJPROP_ANCHOR, ANCHOR_LEFT);
      } else {
         ObjectMove(0, lbl, 0, labelTime, price);
      }
   }
}

void DeleteAllLines() {
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--) {
      string name = ObjectName(0, i);
      if(StringFind(name, "GL_") == 0) ObjectDelete(0, name);
   }
}

void UpdateAllLevels() {
   DeleteAllLines();

   double high, low, close;
   if(!GetPrevDayData(high, low, close)) return;
   glPrevHigh = high; glPrevLow = low; glPrevClose = close;
   GetSwingHL();

   if(InpShowPivot) {
      glPivot = CalcPivots(InpPivotType, high, low, close);
      CreateLine("GL_PP", glPivot.PP, InpColorPivot, InpLineWidth, "PP");
      CreateLine("GL_R1", glPivot.R1, InpColorPivot, InpLineWidth, "R1");
      CreateLine("GL_R2", glPivot.R2, InpColorPivot, InpLineWidth, "R2");
      if(glPivot.R3 > 0) CreateLine("GL_R3", glPivot.R3, InpColorPivot, InpLineWidth, "R3");
      if(glPivot.R4 > 0) CreateLine("GL_R4", glPivot.R4, InpColorPivot, InpLineWidth, "R4");
      CreateLine("GL_S1", glPivot.S1, InpColorPivot, InpLineWidth, "S1");
      CreateLine("GL_S2", glPivot.S2, InpColorPivot, InpLineWidth, "S2");
      if(glPivot.S3 > 0) CreateLine("GL_S3", glPivot.S3, InpColorPivot, InpLineWidth, "S3");
      if(glPivot.S4 > 0) CreateLine("GL_S4", glPivot.S4, InpColorPivot, InpLineWidth, "S4");
   }

   if(InpShowPrevDayHL) {
      CreateLine("GL_PrevHigh", high, InpColorPrevDay, InpLineWidth, "Prev High");
      CreateLine("GL_PrevLow", low, InpColorPrevDay, InpLineWidth, "Prev Low");
   }

   if(InpShowAsianRange) {
      GetAsianRange(glAsianHigh, glAsianLow, glAsianMid);
      if(glAsianHigh > 0) {
         CreateLine("GL_AsianHigh", glAsianHigh, InpColorAsian, InpLineWidth, "Asian High");
         CreateLine("GL_AsianLow", glAsianLow, InpColorAsian, InpLineWidth, "Asian Low");
         CreateLine("GL_AsianMid", glAsianMid, InpColorAsian, InpLineWidth, "Asian Mid");
      }
   }

   if(InpShowSwingHL && glSwingHigh > 0 && glSwingLow < 1000000) {
      CreateLine("GL_SwingHigh", glSwingHigh, InpColorSwing, InpLineWidth, "Swing H");
      CreateLine("GL_SwingLow", glSwingLow, InpColorSwing, InpLineWidth, "Swing L");
   }

   if(InpShowTodayHL) {
      double todayHigh = iHigh(_Symbol, PERIOD_D1, 0);
      double todayLow = iLow(_Symbol, PERIOD_D1, 0);
      if(todayHigh > 0) CreateLine("GL_TodayHigh", todayHigh, InpColorToday, InpLineWidth, "Today H");
      if(todayLow > 0) CreateLine("GL_TodayLow", todayLow, InpColorToday, InpLineWidth, "Today L");
   }

   ChartRedraw();
}

//================ TREND / SETUP ==================
string GetLastH1Direction() {
   double close1 = iClose(_Symbol, PERIOD_H1, 1);
   double open1  = iOpen(_Symbol, PERIOD_H1, 1);
   if(close1 > open1) return "BULLISH";
   if(close1 < open1) return "BEARISH";
   return "NEUTRAL";
}

string GetLastH4Direction() {
   double close1 = iClose(_Symbol, PERIOD_H4, 1);
   double open1  = iOpen(_Symbol, PERIOD_H4, 1);
   if(close1 > open1) return "BULLISH";
   if(close1 < open1) return "BEARISH";
   return "NEUTRAL";
}

double GetEMAOnTF(int period, ENUM_TIMEFRAMES tf, int shift = 0) {
   double ema[];
   ArraySetAsSeries(ema, true);
   int emaHandle = iMA(_Symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if(emaHandle != INVALID_HANDLE && CopyBuffer(emaHandle, 0, shift, 1, ema) > 0) return ema[0];
   return 0;
}

string GetPriceVsEMA50() {
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ema50 = GetEMAOnTF(50, PERIOD_H1, 0);
   if(ema50 <= 0) return "N/A";
   if(currentPrice > ema50) return "ABOVE";
   if(currentPrice < ema50) return "BELOW";
   return "AT";
}

string GetPullbackStatus() {
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   double ema21 = GetEMAOnTF(21, tf);
   double ema50 = GetEMAOnTF(50, tf);

   if(ema21 <= 0 || ema50 <= 0) return "NO-TRADE ZONE";

   double lowBand = MathMin(ema21, ema50);
   double highBand = MathMax(ema21, ema50);
   if(price > lowBand && price < highBand) return "NO-TRADE ZONE";

   if(ema21 > ema50) return "BUY PULLBACKS";
   if(ema21 < ema50) return "SELL PULLBACKS";
   return "NO-TRADE ZONE";
}

color GetPullbackStatusColor() {
   string status = GetPullbackStatus();
   string bias = GetPriceVsEMA50();

   if((status == "BUY PULLBACKS" && bias == "ABOVE") ||
      (status == "SELL PULLBACKS" && bias == "BELOW")) return clrSoftBlue;

   return clrText;
}

//================ TRADE HELPERS ================
double GetATR() {
   double buf[];
   if(CopyBuffer(ATR_handle, 0, 0, 1, buf) > 0) return buf[0];
   return 0;
}

double GetCurrentATR() {
   return GetATR();
}

void UpdatePositionTicket() {
   if(glPositionTicket != 0 && PositionSelectByTicket(glPositionTicket)) return;

   glPositionTicket = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      glPositionTicket = ticket;
      glEntryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      autoBEApplied = false;
      break;
   }
}

bool ReadPendingPrice(double &price) {
   string s = ObjectGetString(0, "pending_price_edit", OBJPROP_TEXT);
   double p = StringToDouble(s);
   if(p <= 0) return false;

   price = NormalizeDouble(p, _Digits);
   return true;
}

double NormalizeVolumeToStep(double vol) {
   double vMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vMax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(vStep <= 0) vStep = 0.01;

   double normalized = MathFloor(vol / vStep) * vStep;
   if(normalized < vMin) normalized = 0.0;
   if(normalized > vMax) normalized = vMax;
   return NormalizeDouble(normalized, 2);
}

bool BuildSplitVolumes(double baseLot, double &v1, double &v2, double &v3, double &v4) {
   v1 = NormalizeVolumeToStep(baseLot * 0.30);
   v2 = NormalizeVolumeToStep(baseLot * 0.30);
   v3 = NormalizeVolumeToStep(baseLot * 0.20);
   v4 = NormalizeVolumeToStep(baseLot * 0.20);
   return (v1 > 0 || v2 > 0 || v3 > 0 || v4 > 0);
}

double GetSplitTPDistance(int idx) {
   if(idx == 0) return SplitTP1_Dollars;
   if(idx == 1) return SplitTP2_Dollars;
   if(idx == 2) return SplitTP3_Dollars;
   return SplitTP4_Dollars;
}

void OpenMarketPosition(bool buy) {
   double price = buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double slDistance = MaxSL_Dollars;

   double sl = buy ? price - slDistance : price + slDistance;
   sl = NormalizeDouble(sl, _Digits);

   bool ok = false;
   if(splitModeEnabled) {
      double v1, v2, v3, v4;
      if(!BuildSplitVolumes(currentLotInput, v1, v2, v3, v4)) {
         Print("Lot too small for split by symbol volume step");
         return;
      }

      double chunks[4] = {v1, v2, v3, v4};
      for(int i = 0; i < 4; i++) {
         if(chunks[i] <= 0) continue;
         double tp = buy ? price + GetSplitTPDistance(i) : price - GetSplitTPDistance(i);
         tp = NormalizeDouble(tp, _Digits);
         bool oneOk = buy
            ? trade.Buy(chunks[i], _Symbol, price, sl, tp)
            : trade.Sell(chunks[i], _Symbol, price, sl, tp);
         ok = oneOk || ok;
      }
   } else {
      double tp = buy ? price + TakeProfitDollars : price - TakeProfitDollars;
      tp = NormalizeDouble(tp, _Digits);
      ok = buy
         ? trade.Buy(currentLotInput, _Symbol, price, sl, tp)
         : trade.Sell(currentLotInput, _Symbol, price, sl, tp);
   }

   if(ok) {
      glPositionTicket = 0;
      glEntryPrice = price;
      autoBEApplied = false;
   }
}

void PlacePendingOrder(bool buyPending) {
   double pendingPrice;
   if(!ReadPendingPrice(pendingPrice)) {
      Print("Invalid pending price");
      return;
   }

   double slDistance = MaxSL_Dollars;

   double sl = buyPending ? pendingPrice - slDistance : pendingPrice + slDistance;
   sl = NormalizeDouble(sl, _Digits);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   bool ok = false;
   if(splitModeEnabled) {
      double v1, v2, v3, v4;
      if(!BuildSplitVolumes(currentLotInput, v1, v2, v3, v4)) {
         Print("Lot too small for split by symbol volume step");
         return;
      }
      double chunks[4] = {v1, v2, v3, v4};
      for(int i = 0; i < 4; i++) {
         if(chunks[i] <= 0) continue;
         double tp = buyPending ? pendingPrice + GetSplitTPDistance(i) : pendingPrice - GetSplitTPDistance(i);
         tp = NormalizeDouble(tp, _Digits);
         bool oneOk = false;
         if(buyPending) {
            oneOk = (pendingPrice <= bid)
               ? trade.BuyLimit(chunks[i], pendingPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "Panel BuyLimit")
               : trade.BuyStop(chunks[i], pendingPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "Panel BuyStop");
         } else {
            oneOk = (pendingPrice >= ask)
               ? trade.SellLimit(chunks[i], pendingPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "Panel SellLimit")
               : trade.SellStop(chunks[i], pendingPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "Panel SellStop");
         }
         ok = oneOk || ok;
      }
   } else {
      double tp = buyPending ? pendingPrice + TakeProfitDollars : pendingPrice - TakeProfitDollars;
      tp = NormalizeDouble(tp, _Digits);
      if(buyPending) {
         ok = (pendingPrice <= bid)
            ? trade.BuyLimit(currentLotInput, pendingPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "Panel BuyLimit")
            : trade.BuyStop(currentLotInput, pendingPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "Panel BuyStop");
      } else {
         ok = (pendingPrice >= ask)
            ? trade.SellLimit(currentLotInput, pendingPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "Panel SellLimit")
            : trade.SellStop(currentLotInput, pendingPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "Panel SellStop");
      }
   }

   if(ok) Print("Pending order placed at ", DoubleToString(pendingPrice, _Digits));
}

void ProtectRemainingPositions() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double current = PositionGetDouble(POSITION_PRICE_CURRENT);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);

      double move = isBuy ? (current - entry) : (entry - current);
      if(move < GroupSLMoveTriggerDollars) continue;

      double targetSL = isBuy ? entry + GroupSLMoveOffsetDollars : entry - GroupSLMoveOffsetDollars;
      targetSL = NormalizeDouble(targetSL, _Digits);

      bool better = (isBuy && targetSL > currentSL) || (!isBuy && (currentSL == 0 || targetSL < currentSL));
      if(better) trade.PositionModify(ticket, targetSL, currentTP);
   }
}

void ManualBE() {
   if(!PositionSelectByTicket(glPositionTicket)) return;

   bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double entry = glEntryPrice;
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);

   double newSL = isBuy ? entry + BE_FixedOffsetDollars : entry - BE_FixedOffsetDollars;
   newSL = NormalizeDouble(newSL, _Digits);

   bool better = (isBuy && newSL > currentSL) || (!isBuy && (currentSL == 0 || newSL < currentSL));
   if(better) trade.PositionModify(glPositionTicket, newSL, currentTP);
}

void CheckAutoMoveSLTo30Percent() {
   if(!PositionSelectByTicket(glPositionTicket) || autoBEApplied) return;

   bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double entry = glEntryPrice;
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);

   if(entry <= 0 || currentTP <= 0) return;

   double fullPath = MathAbs(currentTP - entry);
   if(fullPath <= 0) return;

   double donePath = isBuy ? (currentPrice - entry) : (entry - currentPrice);
   if(donePath <= 0) return;

   double donePercent = (donePath / fullPath) * 100.0;
   if(donePercent < AutoBE_TriggerToTPPercent) return;

   double newSL = isBuy
      ? entry + fullPath * (AutoBE_MoveToTPPercent / 100.0)
      : entry - fullPath * (AutoBE_MoveToTPPercent / 100.0);

   newSL = NormalizeDouble(newSL, _Digits);

   bool better = (isBuy && newSL > currentSL) || (!isBuy && (currentSL == 0 || newSL < currentSL));
   if(!better) {
      autoBEApplied = true;
      return;
   }

   if(trade.PositionModify(glPositionTicket, newSL, currentTP)) autoBEApplied = true;
}

//================ DISPLAY ==================
void UpdateDisplay() {
   int y = GetInfoBlockStartY();

   string h1 = GetLastH1Direction();
   string h4 = GetLastH4Direction();
   string trendText = "H1: " + h1 + " | H4: " + h4 + " | EMA50: " + GetPriceVsEMA50();
   color trendColor = (h1 == "BULLISH") ? clrTrend : (h1 == "BEARISH") ? clrBearish : clrText;
   CreateOrUpdateLabel("trend_line", UI_TEXT_X, y, trendText, 11, trendColor);
   y = NextLineY(y, 11);

   string setupText = "21/50 setup (" + EnumToString((ENUM_TIMEFRAMES)_Period) + "): " + GetPullbackStatus();
   CreateOrUpdateLabel("setup_line", UI_TEXT_X, y, setupText, 11, GetPullbackStatusColor());
   y = NextLineY(y, 11);

   CreateOrUpdateLabel("atr_line", UI_TEXT_X, y, "ATR: " + DoubleToString(GetCurrentATR(), 2) + "$", 11, clrText);
   y = NextLineY(y, 11, 4);

   if(PositionSelectByTicket(glPositionTicket)) {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      color profitColor = profit >= 0 ? MakeColor(80, 200, 80) : MakeColor(230, 80, 80);

      CreateOrUpdateLabel("profit_line", UI_TEXT_X, y, "P/L: $" + DoubleToString(profit, 2), 14, profitColor);
      y = NextLineY(y, 14);

      string slText = (currentSL > 0) ? StringFormat("SL: %.2f", currentSL) : "SL: --";
      string tpText = (currentTP > 0) ? StringFormat("TP: %.2f", currentTP) : "TP: --";
      CreateOrUpdateLabel("sl_line", UI_TEXT_X, y, slText, 12, clrText);
      y = NextLineY(y, 12);
      CreateOrUpdateLabel("tp_line", UI_TEXT_X, y, tpText, 12, clrText);
      y = NextLineY(y, 12);

      double risk = MathAbs(glEntryPrice - currentSL);
      double reward = MathAbs(currentTP - glEntryPrice);
      double rr = (reward > 0 && risk > 0) ? reward / risk : 0;
      CreateOrUpdateLabel("rr_line", UI_TEXT_X, y, StringFormat("R/R: %.2f | Px: %.2f", rr, price), 12, clrText);
   } else {
      CreateOrUpdateLabel("profit_line", UI_TEXT_X, y, "P/L: --", 14, clrText);
      y = NextLineY(y, 14);
      CreateOrUpdateLabel("sl_line", UI_TEXT_X, y, "SL: --", 12, clrText);
      y = NextLineY(y, 12);
      CreateOrUpdateLabel("tp_line", UI_TEXT_X, y, "TP: --", 12, clrText);
      y = NextLineY(y, 12);
      CreateOrUpdateLabel("rr_line", UI_TEXT_X, y, "R/R: --", 12, clrText);
   }
}

int OnInit() {
   ATR_handle = iATR(_Symbol, PERIOD_M5, 14);
   CleanupLegacyObjects();
   splitModeEnabled = InpUseSplitMode;

   if(!MQLInfoInteger(MQL_TESTER)) {
      int x = UI_START_X;
      int y = UI_START_Y;

      CreateLabel("lot_label", x, y, "Lot:", 12, clrWhite);
      CreateEdit("lot_edit", x + 40, y - 3, 70, 25, DoubleToString(currentLotInput, 2));

      CreateLabel("pending_price_label", x + 130, y, "Pending Price:", 12, clrWhite);
      CreateEdit("pending_price_edit", x + 265, y - 3, 120, 25,
                 DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits));

      y += 35;
      CreateButton("SELL", "SELL", x, y, UI_BUTTON_WIDTH, MakeColor(180, 40, 40));
      CreateButton("BUY", "BUY", x + UI_BUTTON_WIDTH + UI_BUTTON_SPACING_X, y, UI_BUTTON_WIDTH, MakeColor(30, 140, 70));

      y += UI_BUTTON_HEIGHT + UI_BUTTON_SPACING_Y;
      CreateButton("SELL_LIMIT", "SELL LIMIT", x, y, UI_BUTTON_WIDTH, MakeColor(160, 70, 70));
      CreateButton("BUY_LIMIT", "BUY LIMIT", x + UI_BUTTON_WIDTH + UI_BUTTON_SPACING_X, y, UI_BUTTON_WIDTH, MakeColor(60, 130, 90));

      y += UI_BUTTON_HEIGHT + UI_BUTTON_SPACING_Y;
      string beText = "BE +" + DoubleToString(BE_FixedOffsetDollars, 1) + "$";
      CreateButton("BE", beText, x, y, UI_BUTTON_WIDTH * 2 + UI_BUTTON_SPACING_X, MakeColor(80, 140, 200));

      y += UI_BUTTON_HEIGHT + UI_BUTTON_SPACING_Y;
      CreateButton("REFRESH_LEVELS", "REFRESH", x, y, UI_BUTTON_WIDTH * 2 + UI_BUTTON_SPACING_X, MakeColor(100, 100, 100));

      y += UI_BUTTON_HEIGHT + UI_BUTTON_SPACING_Y;
      CreateButton("SPLIT_MODE", "", x, y, UI_BUTTON_WIDTH * 2 + UI_BUTTON_SPACING_X, MakeColor(70, 150, 220));
      UpdateSplitModeButton();
   }

   UpdateAllLevels();
   BringPanelControlsToFront();
   UpdateDisplay();
   ChartRedraw();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   if(ATR_handle != INVALID_HANDLE) IndicatorRelease(ATR_handle);

   string objs[] = {
      "lot_label", "lot_edit", "pending_price_label", "pending_price_edit",
      "BUY", "SELL", "BUY_LIMIT", "SELL_LIMIT", "BE", "REFRESH_LEVELS", "SPLIT_MODE",
      "trend_line", "setup_line", "atr_line", "profit_line", "sl_line", "tp_line", "rr_line"
   };

   for(int i = 0; i < ArraySize(objs); i++) ObjectDelete(0, objs[i]);
   CleanupLegacyObjects();
}

void OnChartEvent(const int id, const long &l, const double &d, const string &s) {
   if(id == CHARTEVENT_OBJECT_CLICK) {
      if(s == "BUY") OpenMarketPosition(true);
      if(s == "SELL") OpenMarketPosition(false);
      if(s == "BUY_LIMIT") PlacePendingOrder(true);
      if(s == "SELL_LIMIT") PlacePendingOrder(false);
      if(s == "BE") ManualBE();
      if(s == "REFRESH_LEVELS") UpdateAllLevels();
      if(s == "SPLIT_MODE") {
         splitModeEnabled = !splitModeEnabled;
         UpdateSplitModeButton();
      }

      ObjectSetInteger(0, s, OBJPROP_STATE, false);
      BringPanelControlsToFront();
      UpdateDisplay();
      ChartRedraw();
   }

   if(id == CHARTEVENT_OBJECT_ENDEDIT && s == "lot_edit") {
      string lotString = ObjectGetString(0, "lot_edit", OBJPROP_TEXT);
      double newLot = StringToDouble(lotString);

      if(newLot >= 0.01 && newLot <= 10.0) currentLotInput = NormalizeDouble(newLot, 2);
      else ObjectSetString(0, "lot_edit", OBJPROP_TEXT, DoubleToString(currentLotInput, 2));
   }
}

void OnTick() {
   static datetime lastLevelsUpdate = 0;
   UpdatePositionTicket();
   ProtectRemainingPositions();

   datetime now = TimeCurrent();
   if(lastLevelsUpdate == 0 || now - lastLevelsUpdate >= 3600) {
      UpdateAllLevels();
      lastLevelsUpdate = now;
   }

   UpdateSplitModeButton();
   BringPanelControlsToFront();
   UpdateDisplay();
   ChartRedraw();
}
