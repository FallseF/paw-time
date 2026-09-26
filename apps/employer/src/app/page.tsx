import Link from "next/link";

const metrics = [
  ["公開中の求人", "1", "件"],
  ["選考待ち", "1", "人"],
  ["今日のシフト", "0", "件"],
  ["未入力の評価", "0", "件"],
] as const;

export default function DashboardPage() {
  return (
    <>
      <header className="pageHeader">
        <div><p className="eyebrow">OVERVIEW</p><h1>おかえりなさい</h1><p>今日の採用と勤務状況を確認しましょう。</p></div>
        <Link className="primaryButton" href="/jobs">求人を作成</Link>
      </header>
      <section className="metricGrid">
        {metrics.map(([label, value, unit]) => (
          <article className="metricCard" key={label}><span>{label}</span><strong>{value}<small>{unit}</small></strong></article>
        ))}
      </section>
      <section className="twoColumns">
        <article className="panel">
          <p className="eyebrow">NEXT ACTION</p>
          <h2>応募者を確認しましょう</h2>
          <p>新しい応募が1件届いています。早めの返答が、良い採用体験と家の成長につながります。</p>
          <Link href="/applications">応募者を見る →</Link>
        </article>
        <article className="panel accentPanel">
          <p className="eyebrow">HOUSE UPDATE</p>
          <h2>次は休憩テーブル</h2>
          <p>あと60 XPで、みんなが集まれる家具が開放されます。</p>
          <Link href="/house">家を見る →</Link>
        </article>
      </section>
    </>
  );
}
