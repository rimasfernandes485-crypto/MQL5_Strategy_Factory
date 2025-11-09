# EA_XAUUSD_Bollinger_H1_v6.0

## 📦 Instalação

### 1. Copiar para MT5
```
MQL5_Strategy_Factory/
  └── Experts/
       └── EA_XAUUSD_Bollinger_H1_v6.0.mq5
  └── Presets/
       └── EA_XAUUSD_Bollinger_H1_v6.0.set
```

### 2. Compilar
- Abra o MetaEditor
- Compile o arquivo .mq5
- Verifique se não há erros

### 3. Configurar Backtest
- Importe o preset EA_XAUUSD_Bollinger_H1_v6.0.set
- Período: 2025-11-09 - últimos 12 meses
- Ativo: XAUUSD
- Timeframe: H1

## ⚙️ Parâmetros

| Parâmetro | Valor Padrão | Descrição |
|-----------|--------------|-----------|
| RiskPercent | 1% | Risco por operação |
| ATR_StopLoss_Multiplier | 2.0x | Multiplicador ATR para SL |
| ATR_TakeProfit_Multiplier | 3.0x | Multiplicador ATR para TP |
| UseRSIFilter | Não | Filtro RSI (opcional) |

## 🎯 Resultados Esperados

- **Win Rate**: 50-60%
- **Profit Factor**: > 1.0
- **Drawdown**: < 5%

## ⚠️ Avisos

- Sempre teste em conta DEMO primeiro
- Monitore os logs com prefixo [Base44]
- Ajuste os parâmetros conforme seu perfil de risco

---
Gerado por Base44 MQL5 Factory v6.0