import type { Application } from "@paw-time/api-contracts";
import { EmptyState } from "../../components/EmptyState";

const statusLabel: Record<Application["status"], string> = {
  applied: "選考待ち",
  selected: "採用",
  rejected: "不採用",
  withdrawn: "辞退",
};

export function ApplicationList({ applications }: { applications: Application[] | null }) {
  if (!applications) {
    return <EmptyState title="APIに接続できません" description="先にAPIを起動してください。" />;
  }
  if (applications.length === 0) {
    return <EmptyState title="応募はまだありません" description="応募が届くとここに表示されます。" />;
  }
  return (
    <div className="cardGrid">
      {applications.map((application) => (
        <article className="personCard" key={application.id}>
          <div className="avatar" aria-hidden="true">猫</div>
          <div>
            <h2>{application.workerDisplayName}</h2>
            <p>{new Date(application.appliedAt).toLocaleString("ja-JP")} に応募</p>
          </div>
          <span className="status status-applied">{statusLabel[application.status]}</span>
        </article>
      ))}
    </div>
  );
}
