import MetaTrader5 as mt5
import json
from datetime import datetime, timedelta
import sys
import os

def connect_mt5():
    """Подключается к MT5"""
    print("🔄 Connecting to MetaTrader 5...")
    
    # Пробуем стандартный путь
    if mt5.initialize():
        print("✅ Connected to MT5")
        return True
    
    # Если не получилось, пробуем найти терминал
    possible_paths = [
        r"C:\Program Files\MetaTrader 5\terminal64.exe",
        r"C:\Program Files\MetaTrader 5\terminal.exe",
        r"C:\Program Files (x86)\MetaTrader 5\terminal.exe",
        r"C:\Users\ASUS\AppData\Local\Programs\MetaTrader 5\terminal64.exe"
    ]
    
    for path in possible_paths:
        if os.path.exists(path):
            print(f"🔄 Trying path: {path}")
            if mt5.initialize(path):
                print(f"✅ Connected using: {path}")
                return True
    
    print("❌ Failed to connect to MT5")
    print(f"   Last error: {mt5.last_error()}")
    return False

def get_account_info():
    """Получает информацию о счете"""
    account = mt5.account_info()
    if account:
        return {
            'login': account.login,
            'balance': account.balance,
            'equity': account.equity,
            'profit': account.profit,
            'currency': account.currency,
            'server': account.server,
            'company': account.company
        }
    return None

def format_duration(seconds):
    """Форматирует длительность"""
    if seconds <= 0:
        return ''
    days = seconds // 86400
    hours = (seconds % 86400) // 3600
    minutes = (seconds % 3600) // 60
    secs = seconds % 60
    parts = []
    if days > 0:
        parts.append(f"{days}д")
    if hours > 0:
        parts.append(f"{hours}ч")
    if minutes > 0:
        parts.append(f"{minutes}м")
    if secs > 0 or not parts:
        parts.append(f"{secs}с")
    return ' '.join(parts)

def get_trades_from_mt5(days_back=90):
    """Получает все закрытые позиции (сделки)"""
    
    if not connect_mt5():
        return []

    # Информация о счете
    account = get_account_info()
    if account:
        print(f"\n📊 Account Info:")
        print(f"   Login: {account['login']}")
        print(f"   Balance: {account['balance']:.2f} {account['currency']}")
        print(f"   Equity: {account['equity']:.2f} {account['currency']}")
        print(f"   Server: {account['server']}")
    else:
        print("⚠️  Could not get account info (maybe not logged in?)")
        mt5.shutdown()
        return []

    # Дата начала
    from_date = datetime.now() - timedelta(days=days_back)
    print(f"\n📅 Fetching positions since: {from_date.strftime('%Y.%m.%d %H:%M:%S')}")
    print(f"   Current time: {datetime.now().strftime('%Y.%m.%d %H:%M:%S')}")

    # Получаем историю позиций (закрытые)
    positions = mt5.history_positions_get(from_date, datetime.now())
    
    if positions is None:
        print(f"❌ Error getting positions: {mt5.last_error()}")
        mt5.shutdown()
        return []

    print(f"📊 Total positions found: {len(positions)}")

    # Фильтруем только закрытые позиции
    closed_positions = [p for p in positions if p.time_close > 0]
    print(f"📊 Closed positions: {len(closed_positions)}")
    
    if len(closed_positions) == 0:
        print("\n⚠️  No closed positions found in the specified period")
        print("   Try increasing days_back or check if you have any closed trades")
        mt5.shutdown()
        return []

    trades = []
    for pos in closed_positions:
        open_time = datetime.fromtimestamp(pos.time)
        close_time = datetime.fromtimestamp(pos.time_close)
        duration_seconds = int((close_time - open_time).total_seconds())

        trade = {
            'time': open_time.isoformat(),
            'close_time': close_time.isoformat(),
            'duration_seconds': duration_seconds,
            'duration': format_duration(duration_seconds),
            'position_id': str(pos.ticket),
            'symbol': pos.symbol,
            'type': 'buy' if pos.type == mt5.POSITION_TYPE_BUY else 'sell',
            'volume': pos.volume,
            'price': pos.price_open,
            'close_price': pos.price_close,
            'profit': pos.profit,
            'commission': pos.commission,
            'swap': pos.swap,
            'comment': pos.comment or ''
        }
        trades.append(trade)

    mt5.shutdown()
    return trades

def save_trades_to_json(trades, output_file='trades.json'):
    """Сохраняет сделки в JSON"""
    if not trades:
        return False

    winning = [t for t in trades if t['profit'] > 0]
    losing = [t for t in trades if t['profit'] < 0]

    result = {
        'trades': trades,
        'statistics': {
            'total_trades': len(trades),
            'total_profit': sum(t['profit'] for t in trades if t['profit'] > 0),
            'total_loss': sum(t['profit'] for t in trades if t['profit'] < 0),
            'net_profit': sum(t['profit'] for t in trades),
            'winning_trades': len(winning),
            'losing_trades': len(losing),
        }
    }

    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(f"\n✅ Saved {len(trades)} trades to {output_file}")
    print(f"💰 Net profit: {result['statistics']['net_profit']:.2f}")
    print(f"📈 Winning: {result['statistics']['winning_trades']} ({result['statistics']['winning_trades']/len(trades)*100:.1f}%)")
    print(f"📉 Losing: {result['statistics']['losing_trades']} ({result['statistics']['losing_trades']/len(trades)*100:.1f}%)")
    
    # Статистика по длительности
    trades_with_duration = [t for t in trades if t['duration_seconds'] > 0]
    if trades_with_duration:
        avg_duration = sum(t['duration_seconds'] for t in trades_with_duration) / len(trades_with_duration)
        print(f"⏱️  Avg duration: {format_duration(int(avg_duration))}")

    # Показываем пример
    if trades:
        print("\n📋 Example trade:")
        ex = trades[0]
        print(f"   Symbol: {ex['symbol']}")
        print(f"   Type: {ex['type']}")
        print(f"   Volume: {ex['volume']}")
        print(f"   Open: {ex['time']}")
        print(f"   Close: {ex['close_time']}")
        print(f"   Duration: {ex['duration']}")
        print(f"   Profit: {ex['profit']:.2f}")
    
    return True

if __name__ == '__main__':
    print("=" * 50)
    print("Trading Journal - MT5 Loader")
    print("=" * 50)
    print()
    
    # Параметры
    days = 90
    if len(sys.argv) > 1:
        try:
            days = int(sys.argv[1])
        except:
            pass
    
    print(f"Loading trades for the last {days} days...")
    print()
    
    trades = get_trades_from_mt5(days_back=days)
    
    if trades:
        save_trades_to_json(trades)
        sys.exit(0)
    else:
        print("\n❌ No trades loaded from MT5")
        print("\nPlease check:")
        print("  1. MetaTrader 5 is RUNNING")
        print("  2. You are LOGGED IN to your account")
        print("  3. You have closed positions in the last 90 days")
        print("  4. The terminal is not busy with other operations")
        sys.exit(1)