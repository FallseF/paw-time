import houseCatalog from "@paw-time/game-catalog/employer-house";
import type { GameWorld } from "@paw-time/api-contracts";

export function HouseCard({ world }: { world: GameWorld | null }) {
  const level = world?.level ?? 1;
  const experience = world?.experience ?? 0;
  const next = houseCatalog.levels.find((entry) => entry.level === level + 1);
  const progress = next ? Math.min(100, Math.round((experience / next.requiredExperience) * 100)) : 100;

  return (
    <article className="houseCard">
      <div className="houseScene" aria-label="企業の家のプレビュー">
        <div className="sun" />
        <div className="house">
          <div className="roof" />
          <div className="wall"><div className="door" /><div className="window" /></div>
        </div>
        <div className="ground" />
      </div>
      <div className="houseInfo">
        <p className="eyebrow">EMPLOYER WORLD</p>
        <h2>{houseCatalog.name}</h2>
        <p>Level {level} · {experience} XP</p>
        <div className="progress"><span style={{ width: `${progress}%` }} /></div>
        <p className="hint">求人公開や勤怠確認など、良い採用体験を積み重ねると家が育ちます。</p>
      </div>
    </article>
  );
}
