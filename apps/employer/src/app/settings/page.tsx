import { Suspense } from "react";
import { Skeleton } from "../../components/ui";
import { SettingsPage } from "../../features/settings/SettingsPage";

export default function Page() {
  return (
    <Suspense fallback={<Skeleton />}>
      <SettingsPage />
    </Suspense>
  );
}
