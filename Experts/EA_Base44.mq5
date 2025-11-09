//+------------------------------------------------------------------+
//|                 EA Base44 - Modelo Inicial                       |
//|      Integração Base44 + GitHub - Fábrica de Estratégias         |
//|------------------------------------------------------------------|
//|  Autor:  Samir Fernandes                                         |
//|  Projeto: MQL5 Strategy Factory                                  |
//|  Versão: 1.0                                                     |
//|  Data:   2025-11-08                                              |
//|------------------------------------------------------------------+
//|  Descrição:                                                      |
//|  Este EA é o modelo base usado para testar e validar a integração|
//|  entre o sistema Base44 e o GitHub. Ele serve como exemplo de    |
//|  boas práticas, estrutura modular e funções essenciais.          |
//+------------------------------------------------------------------+

#property copyright "Samir Fernandes"
#property link      "https://github.com/rimasfernandes485-crypto/MQL5_Strategy_Factory"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

//--- Objetos globais
CTrade trade;

//--- Entradas configuráveis
input double  RiskPercent = 1.0;       // Risco por operação (%)
input int     FastEMA     = 9;         // EMA curta
input int     SlowEMA     = 21;        // EMA longa
input double  Lots        = 0.10;      // Lote fixo
input double  StopLoss    = 300;       // Stop em pontos
input double  TakeProfit  = 600;       // Take Profit em pontos
input bool    UseRisk     = true;      // Calcular lote por risco

//+------------------------------------------------------------------+
//| Função: OnInit - Inicialização do EA                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("EA Base44 inicializado com sucesso!");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Função: OnTick - Lógica principal                                |
//+------------------------------------------------------------------+
void OnTick()
  {
   static datetime lastTradeTime = 0;

   //--- Evita múltiplas entradas no mesmo candle
   if (lastTradeTime == iTime(_Symbol, PERIOD_CURRENT, 0))
      return;

   //--- Calcula as EMAs
   double fast = iMA(_Symbol, PERIOD_CURRENT, FastEMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   double slow = iMA(_Symbol, PERIOD_CURRENT, SlowEMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   double prevFast = iMA(_Symbol, PERIOD_CURRENT, FastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double prevSlow = iMA(_Symbol, PERIOD_CURRENT, SlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);

   //--- Detecta cruzamento de EMAs
   bool cruzouAlta  = (prevFast < prevSlow && fast > slow);
   bool cruzouBaixa = (prevFast > prevSlow && fast < slow);

   //--- Se cruzou para cima → COMPRA
   if (cruzouAlta)
     {
      double sl = NormalizeDouble(Bid - StopLoss * _Point, _Digits);
      double tp = NormalizeDouble(Bid + TakeProfit * _Point, _Digits);
      double lot = CalcularLote(sl);
      trade.Buy(lot, _Symbol, Ask, sl, tp);
      Print("Compra executada: EMA", FastEMA, " cruzou acima da EMA", SlowEMA);
      lastTradeTime = iTime(_Symbol, PERIOD_CURRENT, 0);
     }

   //--- Se cruzou para baixo → VENDA
   if (cruzouBaixa)
     {
      double sl = NormalizeDouble(Ask + StopLoss * _Point, _Digits);
      double tp = NormalizeDouble(Ask - TakeProfit * _Point, _Digits);
      double lot = CalcularLote(sl);
      trade.Sell(lot, _Symbol, Bid, sl, tp);
      Print("Venda executada: EMA", FastEMA, " cruzou abaixo da EMA", SlowEMA);
      lastTradeTime = iTime(_Symbol, PERIOD_CURRENT, 0);
     }
  }

//+------------------------------------------------------------------+
//| Função: CalcularLote - calcula lote com base no risco ou fixo    |
//+------------------------------------------------------------------+
double CalcularLote(double stopLossPrice)
  {
   if(!UseRisk)
      return(Lots);

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riscoValor = balance * (RiskPercent / 100.0);

   double distancia = MathAbs(stopLossPrice - SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(distancia <= 0)
      return(Lots);

   double valorPorPonto = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double pontosPorLote = distancia / _Point;

   double loteCalculado = riscoValor / (pontosPorLote * valorPorPonto);
   loteCalculado = NormalizeDouble(loteCalculado, 2);

   //--- Garante que o lote respeita os limites do ativo
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(loteCalculado < minLot) loteCalculado = minLot;
   if(loteCalculado > maxLot) loteCalculado = maxLot;

   loteCalculado = MathFloor(loteCalculado / step) * step;
   return(loteCalculado);
  }

//+------------------------------------------------------------------+
//| Função: OnDeinit - Finalização                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("EA Base44 finalizado. Motivo: ", reason);
  }

//+------------------------------------------------------------------+
