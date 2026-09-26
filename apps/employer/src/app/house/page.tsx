import { HouseCard } from "../../features/employer-house/HouseCard";
import { getEmployerWorld } from "../../lib/api";

export const dynamic = "force-dynamic";

export default async function HousePage() {
  const world = await getEmployerWorld();
  return <><header className="pageHeader"><div><p className="eyebrow">GAMIFICATION</p><h1>みんなの家</h1><p>良い採用と勤務体験が、この家を少しずつ育てます。</p></div></header><HouseCard world={world} /></>;
}
