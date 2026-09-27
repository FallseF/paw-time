import { Suspense } from "react";
import { Skeleton } from "../../components/ui";
import { InvitesPage } from "../../features/invites/InvitesPage";

export default function Page() {
  return (
    <Suspense fallback={<Skeleton />}>
      <InvitesPage />
    </Suspense>
  );
}
