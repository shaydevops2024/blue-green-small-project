import os
from datetime import datetime

from flask import Flask, jsonify, request
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)

db_host = os.getenv('DB_HOST', 'db')
db_port = os.getenv('DB_PORT', '5432')
db_user = os.getenv('DB_USER', 'postgres')
db_password = os.getenv('DB_PASSWORD', 'postgres')
db_name = os.getenv('DB_NAME', 'appdb')

app.config['SQLALCHEMY_DATABASE_URI'] = (
    f'postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}'
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)


class History(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    expression = db.Column(db.String(200), nullable=False)
    result = db.Column(db.Float, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


with app.app_context():
    db.create_all()


@app.route('/health')
def health():
    return jsonify({'status': 'ok'})


@app.route('/history', methods=['GET'])
def get_history():
    records = History.query.order_by(History.created_at.desc()).limit(20).all()
    return jsonify([
        {
            'id': r.id,
            'expression': r.expression,
            'result': r.result,
            'created_at': r.created_at.isoformat(),
        }
        for r in records
    ])


@app.route('/history', methods=['POST'])
def add_history():
    data = request.get_json()
    if not data or 'expression' not in data or 'result' not in data:
        return jsonify({'error': 'expression and result are required'}), 400

    record = History(
        expression=data['expression'],
        result=float(data['result']),
    )
    db.session.add(record)
    db.session.commit()
    return jsonify({'id': record.id}), 201


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
