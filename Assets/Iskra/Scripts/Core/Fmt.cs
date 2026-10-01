// «Искра» — форматирование чисел и времени в русском стиле (запятая, «k», «M»)
using System;
using System.Globalization;

namespace Iskra.Core
{
    public static class Fmt
    {
        static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

        static string Fixed(double v, int d) => v.ToString("F" + d, Inv).Replace('.', ',');

        // Целые числа, а с 10 000 — в тысячах и миллионах
        public static string N(double n)
        {
            string s = n < 0 ? "−" : "";
            n = Math.Abs(n);
            if (n >= 1e6) return s + Fixed(n / 1e6, 2) + "M";
            if (n >= 1e4) return s + Fixed(n / 1e3, 1) + "k";
            return s + Math.Floor(n).ToString(Inv);
        }

        public static string N1(double n) => n >= 100 ? N(n) : Fixed(n, 1);

        public static string X(double v, int d = 1) => Fixed(v, d);

        public static string X2(double v) => Fixed(v, 2);

        public static string Time(double sec)
        {
            long t = (long)Math.Floor(sec);
            long h = t / 3600, m = t % 3600 / 60, s = t % 60;
            return h > 0 ? $"{h} ч {m} мин" : m > 0 ? $"{m} мин {s} с" : $"{s} с";
        }

        public static string Clock(double sec)
        {
            long t = (long)Math.Floor(Math.Max(0, sec));
            long h = t / 3600, m = t % 3600 / 60, x = t % 60;
            return h > 0 ? $"{h}:{m:00}:{x:00}" : $"{m}:{x:00}";
        }
    }

    public static class Rand
    {
        static Random rng = new Random();

        public static void Seed(int seed) => rng = new Random(seed);

        public static double Value => rng.NextDouble();

        public static double Range(double a, double b) => a + rng.NextDouble() * (b - a);

        public static int Int(int maxExclusive) => rng.Next(maxExclusive);

        // Детерминированный генератор для рисунков (как mkRand в веб-версии)
        public static Func<double> Seeded(long seed)
        {
            seed = Math.Max(1, seed % 2147483647);
            return () =>
            {
                seed = seed * 16807 % 2147483647;
                return (seed - 1) / 2147483646.0;
            };
        }
    }
}
