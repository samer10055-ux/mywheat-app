# ماي ويت — تطبيق طلب مباشر

## كيفية النشر (الحصول على رابط عام)

### الخيار الأول: Vercel (الأسهل)
1. أنشئ حسابًا مجانيًا على https://vercel.com
2. ثبّت أداة Vercel: `npm i -g vercel`
3. من داخل هذا المجلد، شغّل: `vercel`
4. اتبع التعليمات، وستحصل على رابط مباشرة (مثال: mywheat-app.vercel.app)

### الخيار الثاني: Netlify
1. أنشئ حسابًا مجانيًا على https://netlify.com
2. اسحب مجلد المشروع (بعد تشغيل `npm run build`) إلى صفحة Netlify Drop:
   https://app.netlify.com/drop
3. سيولّد لك رابطًا فوريًا

### التشغيل محليًا أولاً (اختياري للتجربة)
```
npm install
npm run dev
```

### البناء للإنتاج
```
npm install
npm run build
```
سينتج مجلد `dist` يحتوي على الملفات الجاهزة للرفع على أي استضافة (Vercel, Netlify, GitHub Pages, إلخ).
