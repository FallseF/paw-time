import { AttendancePanel } from "../../features/attendance/AttendancePanel";

export default function AttendancePage() {
  return <><header className="pageHeader"><div><p className="eyebrow">ATTENDANCE</p><h1>勤怠</h1><p>予定と実際の出退勤を確認します。</p></div></header><AttendancePanel /></>;
}
