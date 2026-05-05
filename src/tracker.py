#!/usr/bin/env python3
"""
Hermes Agent Evolution Tracker

Scans Hermes Agent skills, tracks changes over time,
and generates evolution.json for the web dashboard.

Usage:
    python3 tracker.py [--hermes-dir ~/.hermes] [--output ./data] [--snapshot ./data/snapshots/state.json]
"""
import os, sys, json, hashlib, argparse
from datetime import datetime, timezone, timedelta

try:
    import yaml
except ImportError:
    print("⚠️  缺少依赖: pip install pyyaml")
    sys.exit(1)

# ─── Chinese category mapping ───
CATEGORY_CN = {
    "apple": "🍎 Apple 生态",
    "autonomous-ai-agents": "🤖 Agent 管理",
    "creative": "🎨 创意设计",
    "data-science": "📊 数据科学",
    "devops": "🔧 运维部署",
    "dogfood": "🧪 测试 / QA",
    "email": "📧 邮件通讯",
    "gaming": "🎮 游戏",
    "github": "🐙 GitHub 协作",
    "mcp": "🔌 MCP 协议",
    "media": "🎵 媒体影音",
    "mlops": "🧠 AI / 机器学习",
    "note-taking": "📝 笔记知识",
    "productivity": "⚡ 办公效率",
    "red-teaming": "🛡️ 安全 / 红队",
    "research": "🔬 研究发现",
    "smart-home": "🏠 智能家居",
    "social-media": "💬 社交通讯",
    "software-development": "💻 开发工具",
    "yuanbao": "💬 元宝",
    "hermes": "🛠️ Agent 配置",
}

SUBCATEGORY_CN = {
    "evaluation": "评估基准",
    "inference": "推理部署",
    "models": "模型架构",
    "research": "研究框架",
    "training": "训练微调",
}


def get_category(skill_path, skills_dir):
    """Extract Chinese category from skill path"""
    rel = os.path.relpath(skill_path, skills_dir)
    parts = rel.split(os.sep)
    top = parts[0]
    cn = CATEGORY_CN.get(top, top)
    if top == "mlops" and len(parts) > 1 and parts[1] in SUBCATEGORY_CN:
        sub = SUBCATEGORY_CN[parts[1]]
        cn = f"🧠 AI / {sub}"
    return cn


def read_skill_frontmatter(skill_md_path):
    """Read SKILL.md YAML frontmatter, return description"""
    try:
        with open(skill_md_path, 'r', encoding='utf-8') as f:
            content = f.read()
        if content.startswith("---"):
            end = content.find("---", 3)
            if end > 0:
                fm = yaml.safe_load(content[3:end])
                if fm and isinstance(fm, dict):
                    return fm.get("description", "")
    except Exception:
        pass
    return ""


def scan_all_skills(skills_dir):
    """Recursively scan all skills"""
    skills = {}
    for root, dirs, files in os.walk(skills_dir):
        if "SKILL.md" in files:
            skill_md = os.path.join(root, "SKILL.md")
            skill_name = os.path.basename(root)
            desc = read_skill_frontmatter(skill_md)
            cat = get_category(root, skills_dir)
            with open(skill_md, 'rb') as f:
                h = hashlib.md5(f.read()).hexdigest()
            skills[skill_name] = {
                "description": desc,
                "category": cat,
                "hash": h,
                "path": os.path.relpath(root, skills_dir),
            }
    return skills


def read_file_hash(path):
    try:
        with open(path, 'rb') as f:
            return hashlib.md5(f.read()).hexdigest()
    except Exception:
        return ""


def load_usage(skills_dir):
    """Load .usage.json - keys with any data indicate user skills"""
    usage_file = os.path.join(skills_dir, ".usage.json")
    try:
        with open(usage_file, 'r') as f:
            return json.load(f)
    except Exception:
        return {}


def is_user_skill(skill_name, usage):
    """
    A skill is 'user' if its name appears in .usage.json with any data
    (created_at, patch_count, use_count, etc.). Otherwise it's system pre-installed.
    """
    entry = usage.get(skill_name)
    if isinstance(entry, dict) and entry:
        return True
    return False


def load_json(path, default=None):
    try:
        with open(path, 'r') as f:
            return json.load(f)
    except Exception:
        return default if default is not None else {}


def save_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def now_iso():
    return datetime.now(timezone(timedelta(hours=8))).isoformat()


def track(hermes_dir, output_path, snapshot_path):
    skills_dir = os.path.join(hermes_dir, "skills")
    user_md = os.path.join(hermes_dir, "memories", "USER.md")
    memory_md = os.path.join(hermes_dir, "memories", "MEMORY.md")

    if not os.path.isdir(skills_dir):
        print(f"❌ 技能目录不存在: {skills_dir}")
        sys.exit(1)

    current_skills = scan_all_skills(skills_dir)
    usage = load_usage(skills_dir)
    prev = load_json(snapshot_path)
    prev_skills = prev.get("skills", {})
    prev_user_hash = prev.get("user_hash", "")
    prev_memory_hash = prev.get("memory_hash", "")

    now = now_iso()
    events = []
    is_first_run = not prev_skills  # no previous baseline

    # ── Skill change detection ──
    for name, info in current_skills.items():
        source = "user" if is_user_skill(name, usage) else "system"
        if name in prev_skills:
            old = prev_skills[name]
            if old.get("hash") != info["hash"]:
                events.append({
                    "type": "skill_evolved",
                    "category": info["category"],
                    "timestamp": now,
                    "data": {
                        "skill_name": name,
                        "description": info["description"],
                    },
                    "source": source,
                })
        else:
            if not is_first_run:
                events.append({
                    "type": "skill_created",
                    "category": info["category"],
                    "timestamp": now,
                    "data": {
                        "skill_name": name,
                        "description": info["description"],
                    },
                    "source": source,
                })

    # ── User modeling changes ──
    user_hash = read_file_hash(user_md)
    if prev_user_hash:
        # Previous hash exists — compare
        if user_hash and prev_user_hash != user_hash:
            events.append({
                "type": "user_modeling",
                "category": "用户建模",
                "timestamp": now,
                "data": {"description": "用户画像数据发生变化"},
                "source": "user",
            })
    # else: prev_user_hash is empty (first run), just record current hash below

    # ── Memory changes ──
    memory_hash = read_file_hash(memory_md)
    if prev_memory_hash:
        # Previous hash exists — compare
        if memory_hash and prev_memory_hash != memory_hash:
            events.append({
                "type": "memory_changed",
                "category": "长期记忆",
                "timestamp": now,
                "data": {"description": "持久记忆数据发生变化"},
                "source": "user",
            })
    # else: prev_memory_hash is empty (first run), just record current hash below

    # ── Save snapshot ──
    new_snapshot = {
        "timestamp": now,
        "user_hash": user_hash,
        "memory_hash": memory_hash,
        "skills": {
            n: {"hash": i["hash"], "category": i["category"],
                "description": i["description"]}
            for n, i in current_skills.items()
        },
    }
    save_json(snapshot_path, new_snapshot)

    # ── Build skills summary: used vs unused ──
    used_skills = {}
    unused_skills = {}
    for name, info in current_skills.items():
        entry = usage.get(name)
        # Use use_count if available, else 0
        count = 0
        if isinstance(entry, dict):
            count = entry.get("use_count", 0) or entry.get("count", 0) or 0

        skill_entry = {
            "name": name,
            "description": info["description"] or "",
            "usage_count": count,
            "category": info["category"],
            "source": "user" if is_user_skill(name, usage) else "system",
        }
        cat = info["category"]
        if count > 0:
            used_skills.setdefault(cat, []).append(skill_entry)
        else:
            unused_skills.setdefault(cat, []).append(skill_entry)

    for cat in used_skills:
        used_skills[cat].sort(key=lambda x: -x["usage_count"])
    for cat in unused_skills:
        unused_skills[cat].sort(key=lambda x: x["name"])

    # ── Compute stats ──
    user_count = sum(1 for n in current_skills if is_user_skill(n, usage))
    system_count = len(current_skills) - user_count
    used_count = sum(1 for cat_skills in used_skills.values() for _ in cat_skills)
    total_usage = sum(
        (usage.get(n, {}).get("use_count", 0) or usage.get(n, {}).get("count", 0) or 0)
        for n in current_skills if isinstance(usage.get(n), dict)
    )

    evo = {
        "events": events,
        "skills_summary": {
            "used": dict(sorted(used_skills.items())),
            "unused": dict(sorted(unused_skills.items())),
        },
        "stats": {
            "total_skills": len(current_skills),
            "user_skills": user_count,
            "system_skills": system_count,
            "used_skills": used_count,
            "total_usage": total_usage,
            "total_events": len(events),
            "last_scan": now,
        },
    }

    save_json(output_path, evo)

    print(f"✅ 扫描完成: {len(current_skills)} 个技能, {len(events)} 个新事件")
    print(f"   用户技能: {user_count}, 系统技能: {system_count}")
    print(f"   已使用: {used_count}, 总调用次数: {total_usage}")
    if events:
        for e in events:
            src = e.get("source", "system")
            print(f"   → [{src}] {e['type']}: {e['data'].get('skill_name', e['data'].get('description', ''))}")
    else:
        print("   无变化")


def main():
    parser = argparse.ArgumentParser(description="Hermes Agent Evolution Tracker")
    parser.add_argument("--hermes-dir", default=os.environ.get("HERMES_DIR", os.path.expanduser("~/.hermes")),
                        help="Hermes Agent home directory (default: ~/.hermes)")
    parser.add_argument("--output", default=os.environ.get("EVO_OUTPUT", "/opt/hermes-evolution-log/data/evolution.json"),
                        help="Output path for evolution.json (default: /opt/hermes-evolution-log/data/evolution.json)")
    parser.add_argument("--snapshot", default=os.environ.get("EVO_SNAPSHOT", "/opt/hermes-evolution-log/data/snapshots/state.json"),
                        help="Snapshot path (default: /opt/hermes-evolution-log/data/snapshots/state.json)")
    args = parser.parse_args()

    track(args.hermes_dir, args.output, args.snapshot)


if __name__ == "__main__":
    main()
