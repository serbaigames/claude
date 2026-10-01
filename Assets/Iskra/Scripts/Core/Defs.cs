// «Искра» — справочники: ранги, способности, эры, особенности, артефакты, технологии и баланс.
// Перенесено из веб-версии (index.html) без изменения чисел.
using System;
using System.Collections.Generic;

namespace Iskra.Core
{
    public sealed class TierDef
    {
        public string Id, Name, Foe;
        public double Mult, Cd;
        public int Os;
    }

    public sealed class AbilityDef
    {
        public string Id, Icon, Name, Tier, Kind;
        public double Cost, Cd, Base;
    }

    public sealed class EraDef
    {
        public string Id, Name, Icon, Kind, Desc;
        public Dictionary<string, double> Fx;
    }

    public sealed class TraitDef
    {
        public string Id, Name, Icon, Desc;
    }

    public sealed class ArtDef
    {
        public string Id, Name, Icon, Target, Stat, Word;
    }

    public sealed class TechDef
    {
        public string Id, Name, Icon, Desc;
        public int Lvl, Cost;
        public string[] Req;
        public bool Soon;
    }

    public sealed class ParamDef
    {
        public string Id, Name, Desc, Short;
    }

    public static class Defs
    {
        // Коэффициенты баланса (набор C8 из веб-версии)
        public const double MineCost = 30, MineGrow = 1.7, FacCost = 45, FacGrow = 1.75, BonusPow = 0.75;
        public const double FoeHpK = 2.5, FoeAtkK = 0.5, FoeRewardK = 2.5, DefCost = 8, DefGrow = 1.35;
        public const double DevMin = 1.008, DevMax = 1.028, TowerCost = 12, TowerGrow = 1.8;
        public const double GrowthRate = 0.5;           // тьма растёт вдвое медленнее
        public const double AggrMin = 0.7, AggrMax = 1.6; // агрессивность мира
        public const double LegendChance = 0.01;
        public const double EarlyMul = 1.6;             // сущности сильнее в 1,6 раза во всех мирах
        public const double DotT = 6, MendT = 6;         // длительность метки и восстановления, с
        public const double PtGrow = 1.015;              // каждое следующее ОП/ОС дороже на 1,5%
        public const int AbilitySlots = 4;

        public static readonly string[] TierOrder = { "low", "rare", "epic", "legend" };

        public static readonly Dictionary<string, TierDef> Tiers = new Dictionary<string, TierDef>
        {
            ["low"] = new TierDef { Id = "low", Name = "Низшая", Mult = 1, Cd = 2.3, Os = 1, Foe = "Тлеющий сгусток" },
            ["rare"] = new TierDef { Id = "rare", Name = "Редкая", Mult = 2.5, Cd = 2.0, Os = 3, Foe = "Сумрачный страж" },
            ["epic"] = new TierDef { Id = "epic", Name = "Эпическая", Mult = 6, Cd = 1.7, Os = 10, Foe = "Пожиратель света" },
            ["legend"] = new TierDef { Id = "legend", Name = "Легендарная", Mult = 18, Cd = 1.5, Os = 30, Foe = "Сердце бездны" },
        };

        public static readonly ParamDef[] Params =
        {
            new ParamDef { Id = "life", Name = "Жизнь", Desc = "Запас здоровья в бою", Short = "здоровье в бою" },
            new ParamDef { Id = "defense", Name = "Защита", Desc = "Делит урон сущностей тьмы", Short = "делит урон тьмы" },
            new ParamDef { Id = "power", Name = "Мощь", Desc = "Множитель силы атаки", Short = "сила атаки" },
            new ParamDef { Id = "meditation", Name = "Медитация", Desc = "Сколько материи уходит в ход — и насколько он сильнее", Short = "материя и сила хода" },
            new ParamDef { Id = "speed", Name = "Скорость", Desc = "Как быстро откатывается ход", Short = "откат хода" },
            new ParamDef { Id = "control", Name = "Управление", Desc = "Коэффициент защиты, материи и энергии всех ваших клеток: 1 на 1-м уровне, каждый следующий уровень умножает его на 1,01", Short = "защита, материя и энергия клеток" },
        };

        // Порядок важен: из него берётся случайная способность при выпадении (как Object.keys в JS)
        public static readonly List<AbilityDef> AbilityList = new List<AbilityDef>
        {
            Ab("spark_strike", "spark", "Искровой удар", "low", 6, 3, 22, "dmg"),
            Ab("veil", "veil", "Покров", "low", 5, 8, 3, "shield"),
            Ab("feed", "regen", "Подпитка", "low", 6, 5, 14, "heal"),
            Ab("discharge", "bolt", "Разряд", "rare", 12, 5, 60, "dmg"),
            Ab("vampire", "fang", "Вампиризм", "rare", 10, 6, 32, "drain"),
            Ab("haste", "haste", "Ускорение", "rare", 8, 10, 3, "haste"),
            Ab("nova", "nova", "Сверхновая", "epic", 30, 12, 190, "dmg"),
            Ab("dark_shield", "shell", "Щит тьмы", "epic", 20, 14, 3.5, "immune"),
            Ab("absorb", "absorb", "Поглощение", "epic", 25, 12, 0.15, "absorb"),
            Ab("ember", "ember", "Тлеющая метка", "low", 5, 7, 7, "dot"),
            Ab("daze", "daze", "Ошеломление", "low", 5, 9, 1.4, "stunfoe"),
            Ab("mend", "mend", "Восстановление", "low", 6, 10, 2.5, "regenme"),
            Ab("lance", "lance", "Пронзающий луч", "rare", 11, 6, 46, "pierce"),
            Ab("wither", "wither", "Ослабление", "rare", 9, 12, 5, "weaken"),
            Ab("harvest", "harvest", "Жатва", "rare", 10, 8, 34, "harvest"),
            Ab("mirror", "mirror", "Зеркало", "epic", 18, 15, 4.5, "reflect"),
            Ab("finisher", "finisher", "Добивание", "epic", 22, 10, 110, "execute"),
            Ab("dispel", "dispel", "Рассеивание", "epic", 16, 16, 6, "dispel"),
        };

        public static readonly Dictionary<string, AbilityDef> Abilities = new Dictionary<string, AbilityDef>();

        static AbilityDef Ab(string id, string icon, string name, string tier, double cost, double cd, double b, string kind)
            // откаты навыков ×1,3: атака теперь автоматическая
            => new AbilityDef { Id = id, Icon = icon, Name = name, Tier = tier, Cost = cost, Cd = Math.Round(cd * 1.3 * 10) / 10, Base = b, Kind = kind };

        public static readonly Dictionary<string, double> GradeCost = new Dictionary<string, double> { ["low"] = 1, ["rare"] = 1.25, ["epic"] = 1.5 };

        public static readonly EraDef[] Eras =
        {
            Era("dawn", "Тихая заря", "spark", "good", "добыча материи +25%", ("inc", 1.25)),
            Era("drain", "Иссякание", "matter", "bad", "добыча материи −25%", ("inc", 0.75)),
            Era("tide", "Прилив тьмы", "comet", "bad", "тьма растёт в 1,5 раза быстрее", ("grow", 1.5)),
            Era("torpor", "Оцепенение тьмы", "ward", "good", "тьма растёт на 40% медленнее", ("grow", 0.6)),
            Era("flame", "Пламя искры", "rage", "good", "ваш урон +30%", ("pAtk", 1.3)),
            Era("dim", "Тусклый свет", "veil", "bad", "ваш урон −20%", ("pAtk", 0.8)),
            Era("blood", "Кровь бездны", "fang", "bad", "удар сущностей +35%", ("foeAtk", 1.35)),
            Era("brittle", "Хрупкая тьма", "stun", "good", "здоровье сущностей −30%", ("foeHp", 0.7)),
            Era("stone", "Каменная тьма", "shell", "bad", "здоровье сущностей +40%", ("foeHp", 1.4)),
            Era("lore", "Эпоха знаний", "might", "good", "ОП и ОС дешевле на 30%", ("pt", 0.7)),
            Era("toll", "Цена знаний", "leech", "bad", "ОП и ОС дороже на 40%", ("pt", 1.4)),
            Era("builders", "Зодчие", "cells", "good", "шахты и заводы дешевле на 30%", ("bld", 0.7)),
            Era("scarcity", "Дефицит", "erase", "bad", "шахты и заводы дороже на 40%", ("bld", 1.4)),
            Era("bastions", "Бастионы", "shield", "good", "укрепление и башни дешевле на 40%", ("def", 0.6)),
            Era("spoils", "Щедрые трофеи", "core", "good", "награда за победу +60%", ("reward", 1.6)),
            Era("meager", "Скупые трофеи", "clot", "bad", "награда за победу −40%", ("reward", 0.6)),
            Era("starfall", "Звездопад", "nova", "good", "артефакты выпадают в 2,5 раза чаще", ("drop", 2.5)),
            Era("void", "Пустота", "absorb", "bad", "артефакты выпадают втрое реже", ("drop", 0.33)),
            Era("ancients", "Пробуждение древних", "target", "mixed", "легендарные появляются втрое чаще, сущности +10% здоровья", ("leg", 3), ("foeHp", 1.1)),
            Era("bloom", "Расцвет", "regen", "good", "ваши клетки набирают уровни вдвое быстрее", ("held", 2)),
            Era("swift", "Быстрые руки", "haste", "good", "ваши ходы в бою на 20% чаще", ("cd", 0.8)),
            Era("viscous", "Вязкое время", "timer", "bad", "ваши ходы в бою на 25% реже", ("cd", 1.25)),
            Era("balance", "Равновесие", "heart", "mixed", "никаких особых эффектов"),
            Era("eclipse", "Затмение", "bolt", "mixed", "тьма +25% к росту, удар сущностей +15%, но награда +30%", ("inc", 0.85), ("grow", 1.25), ("foeAtk", 1.15), ("reward", 1.3)),
        };

        static EraDef Era(string id, string name, string icon, string kind, string d, params (string k, double v)[] fx)
        {
            var e = new EraDef { Id = id, Name = name, Icon = icon, Kind = kind, Desc = d, Fx = new Dictionary<string, double>() };
            foreach (var (k, v) in fx) e.Fx[k] = v;
            return e;
        }

        // Особенности сущностей: меняют ход боя
        public static readonly string[] TraitOrder = { "regen", "shell", "rage", "ward", "leech", "stun" };
        public static readonly Dictionary<string, TraitDef> Traits = new Dictionary<string, TraitDef>
        {
            ["regen"] = new TraitDef { Id = "regen", Name = "Регенерация", Icon = "regen", Desc = "восстанавливает 1,5% здоровья в секунду" },
            ["shell"] = new TraitDef { Id = "shell", Name = "Панцирь", Icon = "shell", Desc = "получает на 35% меньше урона, пока здоровье выше половины" },
            ["rage"] = new TraitDef { Id = "rage", Name = "Ярость", Icon = "rage", Desc = "при здоровье ниже 40% бьёт в 1,6 раза чаще" },
            ["ward"] = new TraitDef { Id = "ward", Name = "Завеса", Icon = "ward", Desc = "каждые 10 с на 2 с становится неуязвимой" },
            ["leech"] = new TraitDef { Id = "leech", Name = "Иссушение", Icon = "leech", Desc = "каждый удар отнимает у вас материю" },
            ["stun"] = new TraitDef { Id = "stun", Name = "Оглушение", Icon = "stun", Desc = "каждый 4-й удар задерживает ваш ход на 1 с" },
        };

        public static readonly string[] ArtOrder = { "energy", "force", "matter", "clot", "core", "bulwark", "bloom", "frost", "tome", "rune", "glass" };
        public static readonly Dictionary<string, ArtDef> Arts = new Dictionary<string, ArtDef>
        {
            ["energy"] = new ArtDef { Id = "energy", Name = "Кристалл энергии", Stat = "e", Word = "энергии", Icon = "matter", Target = "own" },
            ["force"] = new ArtDef { Id = "force", Name = "Осколок силы", Stat = "f", Word = "силы", Icon = "tri", Target = "own" },
            ["matter"] = new ArtDef { Id = "matter", Name = "Зерно материи", Stat = "m", Word = "материи", Icon = "orb", Target = "own" },
            ["clot"] = new ArtDef { Id = "clot", Name = "Сгусток материи", Icon = "clot", Target = "dark" },
            ["core"] = new ArtDef { Id = "core", Name = "Ядро искры", Icon = "core", Target = "spark" },
            ["bulwark"] = new ArtDef { Id = "bulwark", Name = "Осколок бастиона", Icon = "shield", Target = "own" },
            ["bloom"] = new ArtDef { Id = "bloom", Name = "Семя роста", Icon = "mend", Target = "own" },
            ["frost"] = new ArtDef { Id = "frost", Name = "Иней тьмы", Icon = "ward", Target = "dark" },
            ["tome"] = new ArtDef { Id = "tome", Name = "Свиток силы", Icon = "might", Target = "player" },
            ["rune"] = new ArtDef { Id = "rune", Name = "Руна навыков", Icon = "nova", Target = "player" },
            ["glass"] = new ArtDef { Id = "glass", Name = "Песочные часы", Icon = "timer", Target = "player" },
        };

        public static readonly Dictionary<string, string> ArtShort = new Dictionary<string, string>
        {
            ["energy"] = "+5–50% энергии клетке", ["force"] = "+5–50% силы клетке", ["matter"] = "+5–50% материи клетке",
            ["clot"] = "мощь клетки тьмы ÷2", ["core"] = "база искры ×2–5, навсегда", ["bulwark"] = "защита клетки +10–40%",
            ["bloom"] = "+1–8 мин владения клетке", ["frost"] = "развитие тьмы ×½", ["tome"] = "+5–25 ОП", ["rune"] = "+5–25 ОС", ["glass"] = "сменить эру",
        };

        public static readonly Dictionary<string, double> ArtChance = new Dictionary<string, double> { ["low"] = 0.04, ["rare"] = 0.12, ["epic"] = 0.25, ["legend"] = 1 };
        public static readonly Dictionary<string, double> PulsarChance = new Dictionary<string, double> { ["low"] = 0.005, ["rare"] = 0.015, ["epic"] = 0.04, ["legend"] = 0.25 };

        public static readonly TechDef[] Tech =
        {
            new TechDef { Id = "jump", Lvl = 1, Name = "Прыжок", Icon = "rebirth", Cost = 1, Req = new string[0], Desc = "Открывает прыжок искры в новую область вселенной с бонусами от текущего воплощения." },
            new TechDef { Id = "t2a", Lvl = 2, Name = "Неизвестная технология", Icon = "target", Cost = 0, Req = new[] { "jump" }, Soon = true, Desc = "Откроется в следующих версиях." },
            new TechDef { Id = "t2b", Lvl = 2, Name = "Неизвестная технология", Icon = "target", Cost = 0, Req = new[] { "jump" }, Soon = true, Desc = "Откроется в следующих версиях." },
            new TechDef { Id = "t2c", Lvl = 2, Name = "Неизвестная технология", Icon = "target", Cost = 0, Req = new[] { "jump" }, Soon = true, Desc = "Откроется в следующих версиях." },
        };

        public static readonly string[] Buildings = { "mine", "factory", "tower" };
        public static readonly Dictionary<string, string> BuildingName = new Dictionary<string, string> { ["mine"] = "Шахта", ["factory"] = "Завод", ["tower"] = "Защитная башня" };
        public static readonly Dictionary<string, string> BuildingShort = new Dictionary<string, string> { ["mine"] = "шахта", ["factory"] = "завод", ["tower"] = "башня" };

        // Шестиугольная сетка (осевые координаты)
        public static readonly int[,] Dirs = { { 1, 0 }, { 1, -1 }, { 0, -1 }, { -1, 0 }, { -1, 1 }, { 0, 1 } };

        static Defs()
        {
            foreach (var a in AbilityList) Abilities[a.Id] = a;
        }
    }
}
