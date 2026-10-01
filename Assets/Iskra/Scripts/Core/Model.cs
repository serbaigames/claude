// «Искра» — сохраняемое состояние. Только поля и списки, чтобы его понимал JsonUtility:
// без словарей и null внутри массивов (пустая ячейка способности — запись с пустым id).
using System;
using System.Collections.Generic;

namespace Iskra.Core
{
    [Serializable]
    public class Cell
    {
        public int q, r;
        public bool own, spark, alive;
        public double m, e, f;              // материя, энергия, сила клетки, %
        public double def, defMul = 1;
        public int defLvl;
        public int mine, factory, tower;    // уровни строений
        public double held, age;            // время владения / возраст клетки тьмы, с
        public int lv0 = -1;                // последний объявленный уровень клетки
        public double might, dev, growth, t;
        public string tier = "low";
        public List<string> traits = new List<string>();
        public int inv;

        public string Key => Game.K(q, r);
    }

    [Serializable]
    public class AbilitySlot
    {
        public string id = "";
        public int lvl = 1;
        public long inv;
        public bool Empty => string.IsNullOrEmpty(id);
    }

    [Serializable]
    public class Artifact
    {
        public string type;
        public int v;
    }

    [Serializable]
    public class EraState
    {
        public int i = -1;
        public double left, dur;
    }

    [Serializable]
    public class Kills
    {
        public int low, rare, epic, legend;

        public int this[string tier]
        {
            get => tier == "low" ? low : tier == "rare" ? rare : tier == "epic" ? epic : legend;
            set
            {
                if (tier == "low") low = value;
                else if (tier == "rare") rare = value;
                else if (tier == "epic") epic = value;
                else legend = value;
            }
        }
    }

    [Serializable]
    public class CharStats
    {
        public int life = 1, defense = 1, power = 1, meditation = 1, speed = 1, control = 1;

        public int this[string p]
        {
            get
            {
                switch (p)
                {
                    case "life": return life;
                    case "defense": return defense;
                    case "power": return power;
                    case "meditation": return meditation;
                    case "speed": return speed;
                    default: return control;
                }
            }
            set
            {
                switch (p)
                {
                    case "life": life = value; break;
                    case "defense": defense = value; break;
                    case "power": power = value; break;
                    case "meditation": meditation = value; break;
                    case "speed": speed = value; break;
                    default: control = value; break;
                }
            }
        }

        public int Sum => life + defense + power + meditation + speed + control;
    }

    [Serializable]
    public class GameState
    {
        public int version = 1;
        public double matter = 60, earned;
        public long op, os, opB, osB;       // очки параметров / способностей и сколько их куплено в этом мире
        public CharStats chr = new CharStats();
        public AbilitySlot[] abilities = NewSlots();
        public List<Artifact> artifacts = new List<Artifact>();
        public int rebirths;
        public double bonus;
        public Kills kills = new Kills();
        public double lastWorld;
        public bool introSeen;
        public int bestCells = 1;
        public long saved;
        public int pulsars = 1;
        public List<string> tech = new List<string>();
        public List<int> cores = new List<int>();
        public EraState era = new EraState();
        public int wk;                       // побед в этом мире
        public double we;                    // добыто материи в этом мире
        public double worldTime;
        public double aggr = 1, nextAggr = 1;
        public List<Cell> cells = new List<Cell>();
        public long worldStart;
        public int worldMax = 1;
        public string sel = "";
        public bool lostOnce, paused;
        public int speed = 1;

        public static AbilitySlot[] NewSlots()
        {
            var s = new AbilitySlot[Defs.AbilitySlots];
            for (int i = 0; i < s.Length; i++) s[i] = new AbilitySlot();
            s[0].id = "spark_strike";
            return s;
        }
    }
}
