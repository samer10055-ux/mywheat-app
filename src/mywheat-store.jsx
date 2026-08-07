import React, { useState, useMemo } from "react";

/* =====================================================================
   ماي ويت — واجهة الزبون
   مؤسسة القمحة الذهبية

   عدّل الأسعار والمنتجات من مصفوفة PRODUCTS بالأسفل مباشرة.
   رقم الواتساب: غيّره من ثابت WHATSAPP.
   ===================================================================== */

const WHATSAPP = "9639XXXXXXXX"; // ← ضع رقمك بصيغة دولية بدون +
const CURRENCY = "ل.س";
const MIN_ORDER = 50000;

const CATEGORIES = [
  { id: "all", label: "الكل" },
  { id: "cereal", label: "كورن فليكس" },
  { id: "bars", label: "سيريال بار" },
  { id: "biscuit", label: "بسكويت" },
  { id: "sweets", label: "حلويات" },
  { id: "pasta", label: "معكرونة" },
  { id: "snacks", label: "سناكس" },
];

// tone = لون شريط العلبة (يميّز النكهة على الرف)
const PRODUCTS = [
  { id: 1,  name: "فروت فيتا",   sub: "حلقات فواكه",        cat: "cereal",  tone: "#D2402F", gf: true,  sizes: [{ g: 160, price: 12000 }, { g: 350, price: 24000 }] },
  { id: 2,  name: "فلور ويت",    sub: "بنكهة العسل",         cat: "cereal",  tone: "#D9A521", gf: true,  sizes: [{ g: 160, price: 12000 }, { g: 400, price: 27000 }] },
  { id: 3,  name: "غوريو رينجز", sub: "حلقات شوكولا داكنة",  cat: "cereal",  tone: "#4A2C1D", gf: false, sizes: [{ g: 220, price: 16000 }, { g: 400, price: 28000 }] },
  { id: 4,  name: "ميلثي كورن",  sub: "رقائق ذرة سادة",      cat: "cereal",  tone: "#E0B84C", gf: true,  sizes: [{ g: 250, price: 15000 }, { g: 400, price: 26000 }] },
  { id: 5,  name: "بوبي بالس",   sub: "كرات الشوكولا",       cat: "cereal",  tone: "#6B3A1E", gf: false, sizes: [{ g: 160, price: 13000 }, { g: 350, price: 25000 }] },
  { id: 6,  name: "كرانشي",      sub: "مقرمش",               cat: "cereal",  tone: "#C77C25", gf: false, sizes: [{ g: 220, price: 14000 }] },
  { id: 7,  name: "شوفانتينو",   sub: "بالشوفان",            cat: "cereal",  tone: "#8A7346", gf: false, sizes: [{ g: 350, price: 26000 }] },
  { id: 8,  name: "ميلثي ويت",   sub: "بالنخالة",            cat: "cereal",  tone: "#7A5C3A", gf: false, sizes: [{ g: 400, price: 27000 }] },

  { id: 10, name: "سيريال بار شوكولا",  sub: "علبة ٢٤ حبة", cat: "bars",    tone: "#4A2C1D", gf: false, sizes: [{ g: 30, price: 1500 }] },
  { id: 11, name: "سيريال بار كراميل",  sub: "علبة ٢٤ حبة", cat: "bars",    tone: "#B07A2A", gf: false, sizes: [{ g: 30, price: 1500 }] },
  { id: 12, name: "سيريال بار جوز هند", sub: "علبة ٢٤ حبة", cat: "bars",    tone: "#9C8B70", gf: false, sizes: [{ g: 30, price: 1500 }] },
  { id: 13, name: "سيريال بار قرفة",    sub: "علبة ٢٤ حبة", cat: "bars",    tone: "#A25626", gf: false, sizes: [{ g: 30, price: 1500 }] },

  { id: 20, name: "بيغ برينس",   sub: "بسكويت محشي",         cat: "biscuit", tone: "#3F2A57", gf: false, sizes: [{ g: 220, price: 9000 }] },
  { id: 21, name: "مون",         sub: "بسكويت محشي",         cat: "biscuit", tone: "#2E4A6B", gf: false, sizes: [{ g: 220, price: 9000 }] },
  { id: 22, name: "بسكويت دايجستف", sub: "صحن",              cat: "biscuit", tone: "#8A6236", gf: false, sizes: [{ g: 250, price: 8500 }] },
  { id: 23, name: "بسكويت بالحليب", sub: "صحن",              cat: "biscuit", tone: "#C9B48A", gf: false, sizes: [{ g: 250, price: 8500 }] },

  { id: 30, name: "جيلي بون كولا",  sub: "حلوى جيلي",        cat: "sweets",  tone: "#5B3220", gf: true,  sizes: [{ g: 160, price: 6000 }] },
  { id: 31, name: "جيلي بون فواكه", sub: "حلوى جيلي",        cat: "sweets",  tone: "#D2402F", gf: true,  sizes: [{ g: 160, price: 6000 }] },
  { id: 32, name: "مارشملو توت",    sub: "أصابع",            cat: "sweets",  tone: "#A63A6B", gf: true,  sizes: [{ g: 30, price: 1200 }] },
  { id: 33, name: "دونات",          sub: "نكهات متعددة",     cat: "sweets",  tone: "#C2617E", gf: false, sizes: [{ g: 60, price: 3000 }] },

  { id: 40, name: "معكرونة كوع",  sub: "قمح صلب",            cat: "pasta",   tone: "#C9992E", gf: false, sizes: [{ g: 400, price: 7000 }] },
  { id: 41, name: "معكرونة برغي", sub: "قمح صلب",            cat: "pasta",   tone: "#C9992E", gf: false, sizes: [{ g: 400, price: 7000 }] },
  { id: 42, name: "معكرونة بوري", sub: "قمح صلب",            cat: "pasta",   tone: "#C9992E", gf: false, sizes: [{ g: 400, price: 7000 }] },
  { id: 43, name: "شعيرية",       sub: "قمح صلب",            cat: "pasta",   tone: "#D6AE58", gf: false, sizes: [{ g: 400, price: 6500 }] },

  { id: 50, name: "رز منفوش",          sub: "سادة",          cat: "snacks",  tone: "#D8C9A8", gf: true,  sizes: [{ g: 160, price: 9000 }] },
  { id: 51, name: "رز منفوش شوكولا",   sub: "بالشوكولا",     cat: "snacks",  tone: "#5B3A22", gf: true,  sizes: [{ g: 160, price: 10000 }] },
  { id: 52, name: "شيبس كرسبي",        sub: "مقرمش",         cat: "snacks",  tone: "#D98E1F", gf: false, sizes: [{ g: 30, price: 1500 }] },
  { id: 53, name: "شيبس حار",          sub: "بالفلفل",       cat: "snacks",  tone: "#B8281E", gf: false, sizes: [{ g: 30, price: 1500 }] },
];

const fmt = (n) => n.toLocaleString("ar-EG");

export default function MyWheatStore() {
  const [cat, setCat] = useState("all");
  const [q, setQ] = useState("");
  const [cart, setCart] = useState({});
  const [cartOpen, setCartOpen] = useState(false);

  const shown = useMemo(() => {
    return PRODUCTS.filter((p) => {
      const okCat = cat === "all" || p.cat === cat;
      const okQ = !q.trim() || (p.name + p.sub).includes(q.trim());
      return okCat && okQ;
    });
  }, [cat, q]);

  const lines = useMemo(
    () =>
      Object.entries(cart)
        .filter(([, qty]) => qty > 0)
        .map(([key, qty]) => {
          const [pid, g] = key.split("-").map(Number);
          const p = PRODUCTS.find((x) => x.id === pid);
          const s = p.sizes.find((x) => x.g === g);
          return { key, p, s, qty, total: s.price * qty };
        }),
    [cart]
  );

  const total = lines.reduce((a, l) => a + l.total, 0);
  const count = lines.reduce((a, l) => a + l.qty, 0);

  const bump = (pid, g, delta) => {
    const key = `${pid}-${g}`;
    setCart((c) => {
      const next = Math.max(0, (c[key] || 0) + delta);
      const copy = { ...c };
      if (next === 0) delete copy[key];
      else copy[key] = next;
      return copy;
    });
  };

  const sendOrder = () => {
    const body = lines
      .map((l) => `• ${l.p.name} ${l.s.g}غ × ${l.qty} = ${fmt(l.total)} ${CURRENCY}`)
      .join("\n");
    const msg = `طلب جديد من ماي ويت\n\n${body}\n\nالإجمالي: ${fmt(total)} ${CURRENCY}`;
    window.open(`https://wa.me/${WHATSAPP}?text=${encodeURIComponent(msg)}`, "_blank");
  };

  return (
    <div dir="rtl" className="mw-root">
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Cairo:wght@400;600;900&family=Tajawal:wght@400;500;700&display=swap');

        .mw-root {
          --ink:    #1B1410;
          --field:  #14432F;
          --gold:   #D9A521;
          --paper:  #FBF7F0;
          --clay:   #B8442C;
          --stone:  #6E6257;
          --line:   #E4DACA;
          font-family: 'Tajawal', 'Segoe UI', Tahoma, sans-serif;
          background: var(--paper);
          color: var(--ink);
          min-height: 100vh;
          padding-bottom: 90px;
        }
        .mw-root * { box-sizing: border-box; }

        /* ---------- الترويسة ---------- */
        .mw-head {
          background: var(--field);
          color: var(--paper);
          padding: 22px 18px 26px;
          position: relative;
          overflow: hidden;
        }
        .mw-head::after {
          content: "";
          position: absolute; inset-inline: 0; bottom: 0; height: 6px;
          background: repeating-linear-gradient(90deg, var(--gold) 0 14px, transparent 14px 28px);
        }
        .mw-brand { font-family: 'Cairo', sans-serif; font-weight: 900; font-size: 30px; letter-spacing: -.5px; }
        .mw-brand span { color: var(--gold); }
        .mw-tag { font-size: 13px; opacity: .8; margin-top: 2px; }

        .mw-search {
          width: 100%; margin-top: 16px; padding: 12px 14px;
          border: none; border-radius: 10px; font-size: 15px;
          font-family: inherit; background: rgba(255,255,255,.94); color: var(--ink);
        }
        .mw-search:focus { outline: 3px solid var(--gold); outline-offset: 1px; }

        /* ---------- التصنيفات ---------- */
        .mw-cats {
          display: flex; gap: 8px; overflow-x: auto;
          padding: 14px 18px; border-bottom: 1px solid var(--line);
          background: var(--paper); position: sticky; top: 0; z-index: 5;
        }
        .mw-cats::-webkit-scrollbar { display: none; }
        .mw-cat {
          flex: 0 0 auto; padding: 8px 16px; border-radius: 999px;
          border: 1.5px solid var(--line); background: transparent;
          font-family: inherit; font-size: 14px; font-weight: 500;
          color: var(--stone); cursor: pointer; white-space: nowrap;
        }
        .mw-cat[data-on="true"] { background: var(--ink); border-color: var(--ink); color: var(--paper); }
        .mw-cat:focus-visible { outline: 3px solid var(--gold); outline-offset: 2px; }

        /* ---------- شبكة المنتجات ---------- */
        .mw-grid {
          display: grid; grid-template-columns: repeat(2, 1fr);
          gap: 14px; padding: 18px;
        }
        @media (min-width: 700px) { .mw-grid { grid-template-columns: repeat(3, 1fr); } }
        @media (min-width: 1000px) { .mw-grid { grid-template-columns: repeat(4, 1fr); } }

        /* البطاقة = واجهة علبة */
        .mw-card {
          background: #fff; border: 1px solid var(--line); border-radius: 12px;
          overflow: hidden; display: flex; flex-direction: column;
        }
        .mw-band { height: 68px; position: relative; }
        .mw-seal {
          position: absolute; inset-block-start: 12px; inset-inline-end: 12px;
          width: 44px; height: 44px; border-radius: 50%;
          background: var(--paper); border: 2px solid rgba(0,0,0,.15);
          display: grid; place-content: center; text-align: center;
          font-family: 'Cairo', sans-serif; font-weight: 900;
          font-size: 13px; line-height: 1; color: var(--ink);
        }
        .mw-seal small { display: block; font-size: 8px; font-weight: 600; opacity: .6; }
        .mw-gf {
          position: absolute; inset-block-start: 14px; inset-inline-start: 0;
          background: var(--paper); color: var(--field);
          font-size: 10px; font-weight: 700; padding: 3px 9px 3px 7px;
          border-radius: 0 4px 4px 0;
        }
        .mw-body { padding: 12px; flex: 1; display: flex; flex-direction: column; }
        .mw-name { font-family: 'Cairo', sans-serif; font-weight: 700; font-size: 16px; }
        .mw-sub { font-size: 12px; color: var(--stone); margin-top: 1px; }

        .mw-size {
          display: flex; align-items: center; justify-content: space-between;
          gap: 8px; margin-top: 10px; padding-top: 10px; border-top: 1px dashed var(--line);
        }
        .mw-price { font-family: 'Cairo', sans-serif; font-weight: 700; font-size: 14px; }
        .mw-price small { font-weight: 400; font-size: 11px; color: var(--stone); }

        .mw-step { display: flex; align-items: center; gap: 4px; }
        .mw-btn {
          width: 28px; height: 28px; border-radius: 7px; border: 1.5px solid var(--line);
          background: #fff; font-size: 17px; line-height: 1; cursor: pointer;
          color: var(--ink); font-family: inherit;
        }
        .mw-btn:active { transform: scale(.94); }
        .mw-btn:focus-visible { outline: 3px solid var(--gold); outline-offset: 1px; }
        .mw-add { background: var(--field); border-color: var(--field); color: #fff; }
        .mw-qty { min-width: 20px; text-align: center; font-weight: 700; font-size: 14px; }

        .mw-empty { padding: 60px 20px; text-align: center; color: var(--stone); }

        /* ---------- شريط السلة ---------- */
        .mw-bar {
          position: fixed; inset-inline: 0; bottom: 0; z-index: 20;
          background: var(--ink); color: var(--paper);
          padding: 14px 18px; display: flex; align-items: center;
          justify-content: space-between; gap: 12px;
        }
        .mw-bar-l { font-size: 13px; opacity: .75; }
        .mw-bar-t { font-family: 'Cairo', sans-serif; font-weight: 900; font-size: 19px; }
        .mw-open {
          background: var(--gold); color: var(--ink); border: none;
          padding: 11px 22px; border-radius: 9px; font-family: 'Cairo', sans-serif;
          font-weight: 700; font-size: 15px; cursor: pointer;
        }
        .mw-open:focus-visible { outline: 3px solid var(--paper); outline-offset: 2px; }

        /* ---------- لوحة السلة ---------- */
        .mw-scrim {
          position: fixed; inset: 0; background: rgba(27,20,16,.55); z-index: 30;
        }
        .mw-panel {
          position: fixed; inset-inline: 0; bottom: 0; z-index: 31;
          background: var(--paper); border-radius: 18px 18px 0 0;
          max-height: 86vh; display: flex; flex-direction: column;
          animation: mwUp .22s ease-out;
        }
        @keyframes mwUp { from { transform: translateY(100%); } to { transform: translateY(0); } }
        @media (prefers-reduced-motion: reduce) { .mw-panel { animation: none; } }

        .mw-panel-h {
          padding: 18px; border-bottom: 1px solid var(--line);
          display: flex; align-items: center; justify-content: space-between;
        }
        .mw-panel-t { font-family: 'Cairo', sans-serif; font-weight: 900; font-size: 20px; }
        .mw-x { background: none; border: none; font-size: 26px; cursor: pointer; color: var(--stone); line-height: 1; }
        .mw-list { overflow-y: auto; padding: 8px 18px; flex: 1; }
        .mw-line {
          display: flex; align-items: center; gap: 12px;
          padding: 12px 0; border-bottom: 1px solid var(--line);
        }
        .mw-chip { width: 8px; height: 38px; border-radius: 3px; flex: 0 0 auto; }
        .mw-line-n { font-weight: 700; font-size: 14px; }
        .mw-line-s { font-size: 12px; color: var(--stone); }

        .mw-foot { padding: 18px; border-top: 1px solid var(--line); }
        .mw-sum { display: flex; justify-content: space-between; align-items: baseline; margin-bottom: 12px; }
        .mw-sum-t { font-family: 'Cairo', sans-serif; font-weight: 900; font-size: 24px; }
        .mw-send {
          width: 100%; padding: 15px; border: none; border-radius: 11px;
          background: var(--field); color: #fff; font-family: 'Cairo', sans-serif;
          font-weight: 700; font-size: 16px; cursor: pointer;
        }
        .mw-send:disabled { background: var(--line); color: var(--stone); cursor: not-allowed; }
        .mw-note { font-size: 12px; color: var(--clay); text-align: center; margin-top: 9px; }
      `}</style>

      <header className="mw-head">
        <div className="mw-brand">ماي <span>ويت</span></div>
        <div className="mw-tag">مؤسسة القمحة الذهبية — الطلب المباشر</div>
        <input
          className="mw-search"
          placeholder="دوّر على منتج…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          aria-label="بحث"
        />
      </header>

      <nav className="mw-cats" aria-label="التصنيفات">
        {CATEGORIES.map((c) => (
          <button
            key={c.id}
            className="mw-cat"
            data-on={cat === c.id}
            onClick={() => setCat(c.id)}
          >
            {c.label}
          </button>
        ))}
      </nav>

      {shown.length === 0 ? (
        <div className="mw-empty">ما في منتج بهالاسم. جرّب كلمة تانية أو اختر تصنيف.</div>
      ) : (
        <div className="mw-grid">
          {shown.map((p) => (
            <article key={p.id} className="mw-card">
              <div className="mw-band" style={{ background: p.tone }}>
                {p.gf && <span className="mw-gf">خالي من الغلوتين</span>}
                <span className="mw-seal">
                  {p.sizes[0].g}
                  <small>غرام</small>
                </span>
              </div>
              <div className="mw-body">
                <div className="mw-name">{p.name}</div>
                <div className="mw-sub">{p.sub}</div>

                {p.sizes.map((s) => {
                  const qty = cart[`${p.id}-${s.g}`] || 0;
                  return (
                    <div className="mw-size" key={s.g}>
                      <div className="mw-price">
                        {fmt(s.price)} <small>{CURRENCY} / {s.g}غ</small>
                      </div>
                      <div className="mw-step">
                        {qty > 0 && (
                          <>
                            <button
                              className="mw-btn"
                              onClick={() => bump(p.id, s.g, -1)}
                              aria-label={`إنقاص ${p.name}`}
                            >
                              −
                            </button>
                            <span className="mw-qty">{qty}</span>
                          </>
                        )}
                        <button
                          className="mw-btn mw-add"
                          onClick={() => bump(p.id, s.g, 1)}
                          aria-label={`إضافة ${p.name} ${s.g} غرام`}
                        >
                          +
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            </article>
          ))}
        </div>
      )}

      <div className="mw-bar">
        <div>
          <div className="mw-bar-l">{count > 0 ? `${count} قطعة` : "السلة فاضية"}</div>
          <div className="mw-bar-t">{fmt(total)} {CURRENCY}</div>
        </div>
        <button className="mw-open" onClick={() => setCartOpen(true)} disabled={count === 0}>
          {count > 0 ? "شوف السلة" : "ابدأ الطلب"}
        </button>
      </div>

      {cartOpen && (
        <>
          <div className="mw-scrim" onClick={() => setCartOpen(false)} />
          <div className="mw-panel" role="dialog" aria-label="السلة">
            <div className="mw-panel-h">
              <div className="mw-panel-t">طلبك</div>
              <button className="mw-x" onClick={() => setCartOpen(false)} aria-label="إغلاق">×</button>
            </div>

            <div className="mw-list">
              {lines.length === 0 ? (
                <div className="mw-empty">لسا ما اخترت شي. ارجع واختر من المنتجات.</div>
              ) : (
                lines.map((l) => (
                  <div className="mw-line" key={l.key}>
                    <div className="mw-chip" style={{ background: l.p.tone }} />
                    <div style={{ flex: 1 }}>
                      <div className="mw-line-n">{l.p.name}</div>
                      <div className="mw-line-s">{l.s.g} غرام · {fmt(l.total)} {CURRENCY}</div>
                    </div>
                    <div className="mw-step">
                      <button className="mw-btn" onClick={() => bump(l.p.id, l.s.g, -1)} aria-label="إنقاص">−</button>
                      <span className="mw-qty">{l.qty}</span>
                      <button className="mw-btn mw-add" onClick={() => bump(l.p.id, l.s.g, 1)} aria-label="زيادة">+</button>
                    </div>
                  </div>
                ))
              )}
            </div>

            <div className="mw-foot">
              <div className="mw-sum">
                <span>الإجمالي</span>
                <span className="mw-sum-t">{fmt(total)} {CURRENCY}</span>
              </div>
              <button className="mw-send" onClick={sendOrder} disabled={total < MIN_ORDER}>
                أرسل الطلب على واتساب
              </button>
              {total < MIN_ORDER && (
                <div className="mw-note">
                  أقل طلب {fmt(MIN_ORDER)} {CURRENCY} — باقي {fmt(MIN_ORDER - total)}
                </div>
              )}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
