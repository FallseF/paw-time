"use client";

import Link from "next/link";
import { Empty } from "../components/ui";
import { useConsole } from "../lib/console";

export default function NotFound() {
  const { t } = useConsole();
  return <Empty icon="search" title={t.errors.notFound ?? ""} body={t.errors.notFoundBody} action={<Link className="btn" href="/">{t.errors.goHome}</Link>} />;
}
