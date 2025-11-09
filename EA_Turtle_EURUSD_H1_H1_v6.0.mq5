//+------------------------------------------------------------------+
//| EA_Turtle_EURUSD_H1_H1_v6.0.mq5
//| Base44 MQL5 Strategy Factory
//|------------------------------------------------------------------|
//| Gerado automaticamente pela Base44
//| Repositório: https://github.com/rimasfernandes485-crypto/MQL5_Strategy_Factory
//| Data: 2025-11-09
//| Versão: 6.0
//+------------------------------------------------------------------+
#property copyright "Base44 - MQL5 Strategy Factory"
#property link      "https://github.com/rimasfernandes485-crypto/MQL5_Strategy_Factory"
#property version   "6.00"
#property strict
#property description "Estratégia baseada no sistema Turtle Trading de Richard Dennis. Usa rompimento de canais de Donchian para identificar tendências fortes."
#property description "Timeframe: H1 | Asset: EURUSD"

//--- Parâmetros de entrada
input double RiskPercent = 1;
input double DailyTarget = 5;
input double MaxDailyLoss = 2;
input double MinLotSize = 0.01;
input int MagicNumber = 29567;
input int ATR_Period = 14;
input double ATR_StopLoss_Multiplier = 2.0;
input double ATR_TakeProfit_Multiplier = 3.0;
input bool UseTrailingStop = true;
input double TrailingStop_ATR_Multiplier = 1.5;
input bool UsePinBarFilter = true;
input bool UseMultiTimeframe = true;
input bool UseRSIFilter = false;
input int RSI_Period = 14;
input int RSI_Overbought = 70;
input int RSI_Oversold = 30;

//--- Variáveis globais
int handleMA20, handleMA50, handleMA200, handleATR, handleRSI;
int handleMA200_HTF;
double dailyProfit = 0.0;
datetime lastCheckTime = 0;
int barsTotal = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   Print("[Base44] Inicializando EA v6.0...");
   
   handleMA20 = iMA(_Symbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);
   handleMA50 = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   handleMA200 = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
   handleATR = iATR(_Symbol, PERIOD_H1, ATR_Period);
   handleRSI = iRSI(_Symbol, PERIOD_H1, RSI_Period, PRICE_CLOSE);
   
   ENUM_TIMEFRAMES higherTF = GetHigherTimeframe(PERIOD_H1);
   handleMA200_HTF = iMA(_Symbol, higherTF, 200, 0, MODE_EMA, PRICE_CLOSE);
   
   if(handleMA20 == INVALID_HANDLE || handleMA50 == INVALID_HANDLE || 
      handleMA200 == INVALID_HANDLE || handleATR == INVALID_HANDLE ||
      handleRSI == INVALID_HANDLE || handleMA200_HTF == INVALID_HANDLE)
   {
      Print("[Base44] ❌ Erro ao inicializar indicadores");
      return(INIT_FAILED);
   }
   
   barsTotal = iBars(_Symbol, PERIOD_H1);
   
   Print("[Base44] ===================================================");
   Print("[Base44] ✅ EA v6.0 - ", _Symbol, " H1");
   Print("[Base44] 📊 Configurações:");
   Print("[Base44]    ATR SL: ", ATR_StopLoss_Multiplier, "x | TP: ", ATR_TakeProfit_Multiplier, "x");
   Print("[Base44]    RSI Filter: ", UseRSIFilter ? "ATIVADO" : "DESATIVADO");
   Print("[Base44]    Multi-TF: ", UseMultiTimeframe ? "ATIVADO" : "DESATIVADO");
   Print("[Base44] 💰 Risco: ", RiskPercent, "% | Meta: ", DailyTarget, "%");
   Print("[Base44] ===================================================");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetHigherTimeframe(ENUM_TIMEFRAMES currentTF)
{
   switch(currentTF)
   {
      case PERIOD_M1:  return PERIOD_M5;
      case PERIOD_M5:  return PERIOD_M15;
      case PERIOD_M15: return PERIOD_H1;
      case PERIOD_M30: return PERIOD_H1;
      case PERIOD_H1:  return PERIOD_H4;
      case PERIOD_H4:  return PERIOD_D1;
      case PERIOD_D1:  return PERIOD_W1;
      default:         return PERIOD_H4;
   }
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handleMA20);
   IndicatorRelease(handleMA50);
   IndicatorRelease(handleMA200);
   IndicatorRelease(handleATR);
   IndicatorRelease(handleRSI);
   IndicatorRelease(handleMA200_HTF);
   
   Print("[Base44] EA v6.0 finalizado. Lucro diário: $", dailyProfit);
}

//+------------------------------------------------------------------+
void OnTick()
{
   int bars = iBars(_Symbol, PERIOD_H1);
   bool isNewBar = (bars != barsTotal);
   
   if(isNewBar)
   {
      barsTotal = bars;
      
      if(!CheckDailyLimits()) return;
      ManageOpenPositions();
      CheckForTradingSignals();
   }
   else if(UseTrailingStop)
   {
      ApplyTrailingStopToAll();
   }
}

//+------------------------------------------------------------------+
bool CheckDailyLimits()
{
   datetime currentDay = iTime(_Symbol, PERIOD_D1, 0);
   
   if(currentDay != lastCheckTime)
   {
      dailyProfit = 0.0;
      lastCheckTime = currentDay;
      Print("[Base44] 🌅 Novo dia de trading");
   }
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double targetAmount = accountBalance * DailyTarget / 100.0;
   double maxLossAmount = accountBalance * MaxDailyLoss / 100.0;
   
   if(dailyProfit >= targetAmount)
   {
      Print("[Base44] 🎯 Meta atingida! $", dailyProfit);
      return false;
   }
   
   if(dailyProfit <= -maxLossAmount)
   {
      Print("[Base44] ⛔ Perda máxima! $", dailyProfit);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            CheckExitSignal(PositionGetTicket(i));
         }
      }
   }
}

//+------------------------------------------------------------------+
void ApplyTrailingStopToAll()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            ApplyATRTrailingStop(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
void ApplyATRTrailingStop(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   
   double atr = GetCurrentATR();
   if(atr <= 0) return;
   
   double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double trailingDistance = atr * TrailingStop_ATR_Multiplier;
   double minProfitDistance = atr * 0.5;
   double newSL = 0;
   
   if(posType == POSITION_TYPE_BUY)
   {
      if(currentPrice < positionOpenPrice + minProfitDistance) return;
      
      newSL = currentPrice - trailingDistance;
      
      if(newSL > currentSL && newSL > positionOpenPrice)
      {
         newSL = NormalizeDouble(newSL, _Digits);
         ModifyPosition(ticket, newSL, PositionGetDouble(POSITION_TP));
      }
   }
   else
   {
      if(currentPrice > positionOpenPrice - minProfitDistance) return;
      
      newSL = currentPrice + trailingDistance;
      
      if((currentSL == 0 || newSL < currentSL) && newSL < positionOpenPrice)
      {
         newSL = NormalizeDouble(newSL, _Digits);
         ModifyPosition(ticket, newSL, PositionGetDouble(POSITION_TP));
      }
   }
}

//+------------------------------------------------------------------+
double GetCurrentATR()
{
   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   
   if(CopyBuffer(handleATR, 0, 0, 1, atrValues) < 1)
      return 0;
   
   return atrValues[0];
}

//+------------------------------------------------------------------+
double GetCurrentRSI()
{
   double rsiValues[];
   ArraySetAsSeries(rsiValues, true);
   
   if(CopyBuffer(handleRSI, 0, 0, 1, rsiValues) < 1)
      return 50;
   
   return rsiValues[0];
}

//+------------------------------------------------------------------+
void ModifyPosition(ulong ticket, double sl, double tp)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.symbol = _Symbol;
   request.sl = sl;
   request.tp = tp;
   
   OrderSend(request, result);
}

//+------------------------------------------------------------------+
void CheckExitSignal(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   
   double ma20[], ma50[];
   ArraySetAsSeries(ma20, true);
   ArraySetAsSeries(ma50, true);
   
   if(CopyBuffer(handleMA20, 0, 0, 2, ma20) < 2) return;
   if(CopyBuffer(handleMA50, 0, 0, 2, ma50) < 2) return;
   
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   if(posType == POSITION_TYPE_BUY && ma20[0] < ma50[0])
   {
      Print("[Base44] 🔴 Saída: MA20 < MA50");
      ClosePosition(ticket);
   }
   else if(posType == POSITION_TYPE_SELL && ma20[0] > ma50[0])
   {
      Print("[Base44] 🟢 Saída: MA20 > MA50");
      ClosePosition(ticket);
   }
}

//+------------------------------------------------------------------+
void ClosePosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;

   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = _Symbol;
   request.volume = PositionGetDouble(POSITION_VOLUME);
   request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = (request.type == ORDER_TYPE_SELL) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   request.deviation = 10;
   request.magic = MagicNumber;
   
   OrderSend(request, result);
}

//+------------------------------------------------------------------+
void CheckForTradingSignals()
{
   if(PositionsTotal() > 0) return;
   
   double ma20[], ma50[], ma200[];
   ArraySetAsSeries(ma20, true);
   ArraySetAsSeries(ma50, true);
   ArraySetAsSeries(ma200, true);
   
   if(CopyBuffer(handleMA20, 0, 0, 3, ma20) < 3) return;
   if(CopyBuffer(handleMA50, 0, 0, 3, ma50) < 3) return;
   if(CopyBuffer(handleMA200, 0, 0, 3, ma200) < 3) return;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_H1, 0, 3, rates) < 3) return;
   
   double rsi = GetCurrentRSI();
   
   bool buySignal = false;
   bool sellSignal = false;
   
   // ====== SINAL DE COMPRA ======
   if(ma20[0] > ma50[0] && ma50[0] > ma200[0])
   {
      if(rates[1].close > ma20[0])
      {
         bool passFilters = true;
         
         if(UseRSIFilter && rsi > RSI_Overbought)
         {
            passFilters = false;
            Print("[Base44] ⏸️ Bloqueado: RSI=", rsi);
         }
         
         if(UseMultiTimeframe && !ConfirmTrendHigherTF(true))
         {
            passFilters = false;
         }
         
         if(UsePinBarFilter && IsBearishPinBar(1))
         {
            passFilters = false;
         }
         
         if(passFilters)
         {
            buySignal = true;
            Print("[Base44] 🔔 COMPRA! RSI=", rsi);
         }
      }
   }
   
   // ====== SINAL DE VENDA ======
   if(ma20[0] < ma50[0] && ma50[0] < ma200[0])
   {
      if(rates[1].close < ma20[0])
      {
         bool passFilters = true;
         
         if(UseRSIFilter && rsi < RSI_Oversold)
         {
            passFilters = false;
            Print("[Base44] ⏸️ Bloqueado: RSI=", rsi);
         }
         
         if(UseMultiTimeframe && !ConfirmTrendHigherTF(false))
         {
            passFilters = false;
         }
         
         if(UsePinBarFilter && IsBullishPinBar(1))
         {
            passFilters = false;
         }
         
         if(passFilters)
         {
            sellSignal = true;
            Print("[Base44] 🔔 VENDA! RSI=", rsi);
         }
      }
   }
   
   if(buySignal) OpenPosition(ORDER_TYPE_BUY);
   else if(sellSignal) OpenPosition(ORDER_TYPE_SELL);
}

//+------------------------------------------------------------------+
bool ConfirmTrendHigherTF(bool isBuy)
{
   double ma200HTF[];
   ArraySetAsSeries(ma200HTF, true);
   
   if(CopyBuffer(handleMA200_HTF, 0, 0, 1, ma200HTF) < 1)
      return true;
   
   double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   return isBuy ? (currentPrice > ma200HTF[0]) : (currentPrice < ma200HTF[0]);
}

//+------------------------------------------------------------------+
bool IsBullishPinBar(int shift)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_H1, shift, 1, rates) < 1)
      return false;
   
   double bodySize = MathAbs(rates[0].close - rates[0].open);
   double upperWick = rates[0].high - MathMax(rates[0].open, rates[0].close);
   double lowerWick = MathMin(rates[0].open, rates[0].close) - rates[0].low;
   double totalSize = rates[0].high - rates[0].low;
   
   return (lowerWick > bodySize * 2 && upperWick < bodySize * 0.5 && bodySize < totalSize * 0.3);
}

//+------------------------------------------------------------------+
bool IsBearishPinBar(int shift)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_H1, shift, 1, rates) < 1)
      return false;
   
   double bodySize = MathAbs(rates[0].close - rates[0].open);
   double upperWick = rates[0].high - MathMax(rates[0].open, rates[0].close);
   double lowerWick = MathMin(rates[0].open, rates[0].close) - rates[0].low;
   double totalSize = rates[0].high - rates[0].low;
   
   return (upperWick > bodySize * 2 && lowerWick < bodySize * 0.5 && bodySize < totalSize * 0.3);
}

//+------------------------------------------------------------------+
void OpenPosition(ENUM_ORDER_TYPE orderType)
{
   double lotSize = CalculateLotSize();
   double price = (orderType == ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double atr = GetCurrentATR();
   double sl = 0, tp = 0;
   
   if(atr > 0)
   {
      if(orderType == ORDER_TYPE_BUY)
      {
         sl = price - (atr * ATR_StopLoss_Multiplier);
         tp = price + (atr * ATR_TakeProfit_Multiplier);
      }
      else
      {
         sl = price + (atr * ATR_StopLoss_Multiplier);
         tp = price - (atr * ATR_TakeProfit_Multiplier);
      }
      
      sl = NormalizeDouble(sl, _Digits);
      tp = NormalizeDouble(tp, _Digits);
   }
   else
   {
      Print("[Base44] ⚠️ ATR inválido");
      return;
   }
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = orderType;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "Base44_Turtle_EURUSD_H1";
   request.type_filling = ORDER_FILLING_FOK;
   
   if(OrderSend(request, result))
   {
      Print("[Base44] ✅ Ordem #", result.order);
   }
   else
   {
      Print("[Base44] ❌ Erro: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * RiskPercent / 100.0;
   
   double atr = GetCurrentATR();
   if(atr <= 0) return MinLotSize;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickValue == 0 || tickSize == 0) return MinLotSize;
   
   double stopLossPrice = atr * ATR_StopLoss_Multiplier;
   double stopLossPoints = stopLossPrice / _Point;
   
   double lotSize = riskAmount / (stopLossPoints * tickValue / tickSize);
   lotSize = MathMax(MinLotSize, lotSize);
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(lotStep > 0)
      lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
void OnTrade()
{
   datetime currentDayStart = iTime(_Symbol, PERIOD_D1, 0);
   if(HistorySelect(currentDayStart, TimeCurrent()))
   {
      int totalDeals = HistoryDealsTotal();
      if(totalDeals > 0)
      {
         dailyProfit = 0.0;
         for(int i = 0; i < totalDeals; i++)
         {
            ulong dealTicket = HistoryDealGetTicket(i);
            if(dealTicket > 0)
            {
               if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == MagicNumber)
               {
                  ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
                  if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
                  {
                     double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                     dailyProfit += profit;
                  }
               }
            }
         }
      }
   }
}