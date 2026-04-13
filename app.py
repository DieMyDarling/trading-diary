from flask import Flask, render_template, jsonify, request, send_file
from flask_cors import CORS
import json
import os
import shutil
from datetime import datetime
from typing import Dict, Any

app = Flask(__name__)
CORS(app)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TRADES_FILE = os.path.join(BASE_DIR, 'trades.json')
JOURNAL_FILE = os.path.join(BASE_DIR, 'journal_entries.json')
BACKUP_DIR = os.path.join(BASE_DIR, 'backups')

if not os.path.exists(BACKUP_DIR):
    os.makedirs(BACKUP_DIR)


def load_trades() -> Dict[str, Any]:
    """Загружает сделки из JSON файла"""
    try:
        if not os.path.exists(TRADES_FILE):
            print(f"⚠️ Файл не найден: {TRADES_FILE}")
            return {'trades': [], 'statistics': {}}
        
        with open(TRADES_FILE, 'r', encoding='utf-8') as f:
            data = json.load(f)
            trades = data.get('trades', [])
            # Добавляем поле result для удобства
            for trade in trades:
                if trade.get('profit', 0) > 0:
                    trade['result'] = 'profit'
                elif trade.get('profit', 0) < 0:
                    trade['result'] = 'loss'
                else:
                    trade['result'] = 'breakeven'
            print(f"📊 Загружено {len(trades)} сделок из {TRADES_FILE}")
            return data
    except Exception as e:
        print(f"Ошибка загрузки trades.json: {e}")
        return {'trades': [], 'statistics': {}}


def load_journal() -> Dict[str, Dict[str, Any]]:
    """Загружает записи дневника"""
    try:
        if os.path.exists(JOURNAL_FILE):
            with open(JOURNAL_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        return {}
    except Exception as e:
        print(f"Ошибка загрузки journal_entries.json: {e}")
        return {}


def save_journal(journal: Dict[str, Dict[str, Any]]) -> None:
    """Сохраняет записи дневника"""
    if os.path.exists(JOURNAL_FILE):
        today = datetime.now().strftime('%Y%m%d')
        backup_file = os.path.join(BACKUP_DIR, f'journal_{today}.json')
        
        if not os.path.exists(backup_file):
            try:
                shutil.copy(JOURNAL_FILE, backup_file)
                backups = sorted([f for f in os.listdir(BACKUP_DIR) if f.startswith('journal_')])
                for old in backups[:-30]:
                    os.remove(os.path.join(BACKUP_DIR, old))
                print(f"📦 Создан бэкап: {backup_file}")
            except Exception as e:
                print(f"⚠️ Ошибка создания бэкапа: {e}")
    
    with open(JOURNAL_FILE, 'w', encoding='utf-8') as f:
        json.dump(journal, f, ensure_ascii=False, indent=2)


def calculate_statistics(trades):
    """Пересчитывает статистику"""
    trading_trades = [t for t in trades if t.get('symbol')]
    
    return {
        'total_trades': len(trading_trades),
        'total_profit': sum(t.get('profit', 0) for t in trading_trades if t.get('profit', 0) > 0),
        'total_loss': sum(t.get('profit', 0) for t in trading_trades if t.get('profit', 0) < 0),
        'net_profit': sum(t.get('profit', 0) for t in trading_trades),
        'winning_trades': len([t for t in trading_trades if t.get('profit', 0) > 0]),
        'losing_trades': len([t for t in trading_trades if t.get('profit', 0) < 0]),
    }


@app.route('/')
def index():
    return render_template('index.html')


@app.route('/api/trades')
def get_trades():
    data = load_trades()
    journal = load_journal()
    
    trades = data.get('trades', [])
    
    for trade in trades:
        deal_id = trade.get('position_id') or trade.get('deal_id')
        if deal_id and deal_id in journal:
            trade['journal_entry'] = journal[deal_id]
        else:
            trade['journal_entry'] = None
    
    stats = data.get('statistics')
    if not stats and trades:
        stats = calculate_statistics(trades)
    
    return jsonify({
        'trades': trades,
        'statistics': stats
    })


@app.route('/api/journal/<deal_id>', methods=['GET', 'POST', 'DELETE'])
def handle_journal(deal_id: str):
    journal = load_journal()
    
    if request.method == 'GET':
        return jsonify(journal.get(deal_id, {}))
    
    elif request.method == 'POST':
        data = request.json
        now = datetime.now().isoformat()
        
        journal[deal_id] = {
            'comment': data.get('comment', ''),
            'rating': data.get('rating', 0),
            'tags': data.get('tags', []),
            'mistakes': data.get('mistakes', []),
            'emotion': data.get('emotion', ''),
            'updated_at': now,
            'created_at': journal.get(deal_id, {}).get('created_at', now)
        }
        save_journal(journal)
        return jsonify({'success': True, 'entry': journal[deal_id]})
    
    elif request.method == 'DELETE':
        if deal_id in journal:
            del journal[deal_id]
            save_journal(journal)
        return jsonify({'success': True})


@app.route('/api/statistics')
def get_statistics():
    data = load_trades()
    journal = load_journal()
    trades = data.get('trades', [])
    
    trading_trades = [t for t in trades if t.get('symbol')]
    
    tag_stats = {}
    for deal_id, entry in journal.items():
        for tag in entry.get('tags', []):
            if tag not in tag_stats:
                tag_stats[tag] = {'count': 0, 'total_profit': 0}
            tag_stats[tag]['count'] += 1
    
    for trade in trading_trades:
        deal_id = trade.get('position_id') or trade.get('deal_id')
        if deal_id and deal_id in journal:
            for tag in journal[deal_id].get('tags', []):
                if tag in tag_stats:
                    tag_stats[tag]['total_profit'] += trade.get('profit', 0)
    
    return jsonify({
        'tag_stats': tag_stats,
        'total_journal_entries': len(journal),
        'journal_coverage': round(len(journal) / len(trading_trades) * 100, 1) if trading_trades else 0
    })


@app.route('/api/export')
def export_journal():
    journal = load_journal()
    data = load_trades()
    trades = data.get('trades', [])
    
    trades_dict = {}
    for t in trades:
        deal_id = t.get('position_id') or t.get('deal_id')
        if deal_id:
            trades_dict[deal_id] = t
    
    export_data = []
    for deal_id, entry in journal.items():
        trade = trades_dict.get(deal_id, {})
        export_data.append({
            'deal_id': deal_id,
            'date': trade.get('time'),
            'close_date': trade.get('close_time'),
            'duration': trade.get('duration'),
            'symbol': trade.get('symbol'),
            'type': trade.get('type'),
            'volume': trade.get('volume'),
            'profit': trade.get('profit'),
            'comment': entry.get('comment'),
            'tags': entry.get('tags', []),
            'rating': entry.get('rating', 0),
            'emotion': entry.get('emotion'),
            'mistakes': entry.get('mistakes', []),
            'created_at': entry.get('created_at'),
            'updated_at': entry.get('updated_at')
        })
    
    return jsonify(export_data)


@app.route('/api/reload')
def reload_trades():
    return jsonify({'success': True})


if __name__ == '__main__':
    print("=" * 50)
    print("📊 Торговый дневник")
    print("=" * 50)
    
    if not os.path.exists(TRADES_FILE):
        print(f"⚠️ Файл {TRADES_FILE} не найден!")
        print("Запустите python mt5_loader.py или python working_parser.py")
    else:
        data = load_trades()
        trades = data.get('trades', [])
        print(f"✅ Загружено {len(trades)} сделок")
    
    print(f"📁 База данных дневника: {JOURNAL_FILE}")
    print("\n🚀 Запуск сервера...")
    print("🌐 Откройте в браузере: http://localhost:5000")
    print("=" * 50)
    
    app.run(debug=True, port=5000, extra_files=[TRADES_FILE, JOURNAL_FILE])