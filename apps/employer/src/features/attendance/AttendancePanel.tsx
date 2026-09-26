export function AttendancePanel() {
  return (
    <div className="tableCard">
      <table>
        <thead>
          <tr><th>ワーカー</th><th>予定</th><th>出勤</th><th>退勤</th><th>判定</th></tr>
        </thead>
        <tbody>
          <tr>
            <td><strong>みか</strong></td>
            <td>10:00–15:00</td>
            <td>—</td>
            <td>—</td>
            <td><span className="status status-draft">勤務前</span></td>
          </tr>
        </tbody>
      </table>
      <p className="hint">出勤判定は予定時刻と追記型の勤怠イベントからAPIが計算します。</p>
    </div>
  );
}
