// Настройки страницы поддержки: замените значения на свои ссылки и реквизиты.
// В donateUrl можно использовать {amount}: туда подставится выбранная сумма.
const SUPPORT = {
  donateUrl: "https://www.donationalerts.com/r/ВАШ_НИК",
  subscribeUrl: "https://boosty.to/ВАШ_НИК",
  cardNumber: "0000 0000 0000 0000",
};

// Мобильное меню
const toggle = document.querySelector(".nav-toggle");
const nav = document.querySelector(".nav");
if (toggle && nav) {
  toggle.addEventListener("click", () => {
    const open = nav.classList.toggle("open");
    toggle.setAttribute("aria-expanded", String(open));
  });
  nav.querySelectorAll("a").forEach((a) =>
    a.addEventListener("click", () => nav.classList.remove("open"))
  );
}

// Год в подвале
document.querySelectorAll("#year").forEach((el) => (el.textContent = new Date().getFullYear()));

// Сетка шестигранников на обложке «Искры»
const grid = document.getElementById("hexgrid");
if (grid) {
  const ns = "http://www.w3.org/2000/svg";
  const w = 45, h = 39;
  for (let row = -1; row < 10; row++) {
    for (let col = -1; col < 11; col++) {
      const x = col * w + (row % 2 ? w / 2 : 0);
      const y = row * h;
      const dist = Math.hypot(x - 200, y - 176);
      const use = document.createElementNS(ns, "use");
      use.setAttribute("href", "#hex");
      use.setAttribute("x", x);
      use.setAttribute("y", y);
      use.setAttribute("opacity", Math.max(0.08, 1 - dist / 220).toFixed(2));
      grid.appendChild(use);
    }
  }
}

// Страница поддержки
const donateLink = document.getElementById("donate-link");
if (donateLink) {
  const setAmount = (amount) => {
    donateLink.href = SUPPORT.donateUrl.replace("{amount}", amount);
    donateLink.textContent = `Поддержать на ${amount} ₽`;
  };
  document.querySelectorAll(".amount").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.querySelectorAll(".amount").forEach((b) => b.classList.remove("selected"));
      btn.classList.add("selected");
      setAmount(btn.dataset.amount);
    });
  });
  setAmount(document.querySelector(".amount.selected").dataset.amount);

  document.getElementById("subscribe-link").href = SUPPORT.subscribeUrl;
  document.getElementById("card-number").textContent = SUPPORT.cardNumber;

  document.querySelectorAll(".copy-btn").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const text = document.getElementById(btn.dataset.copy).textContent;
      try {
        await navigator.clipboard.writeText(text);
        btn.textContent = "Скопировано";
      } catch {
        btn.textContent = "Не удалось";
      }
      setTimeout(() => (btn.textContent = "Копировать"), 1500);
    });
  });
}
