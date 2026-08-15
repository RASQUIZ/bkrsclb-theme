(function () {
  var ua = navigator.userAgent || '';
  if (/iPad|iPhone|iPod/.test(ua)) return; // hidden on iOS
  if (document.getElementById('bkrsclb-android-banner')) return; // avoid double-inject

  var apkUrl = 'https://streaming.bkrsclb.com/downloads/THE-BAKERY-v1.0.apk';

  var bar = document.createElement('div');
  bar.id = 'bkrsclb-android-banner';
  bar.style.cssText = [
    'display:flex', 'align-items:center', 'justify-content:center', 'gap:12px',
    'flex-wrap:wrap', 'background:#111111', 'border-top:1px solid #2a2a2a',
    'padding:14px 20px', "font-family:-apple-system,'Helvetica Neue',Arial,sans-serif"
  ].join(';');

  bar.innerHTML =
    '<svg width="20" height="20" viewBox="0 0 24 24" fill="#43A047" aria-hidden="true"><path d="M17.523 15.3414c-.5665 0-1.0243-.4577-1.0243-1.0242 0-.5665.4578-1.0243 1.0243-1.0243.5665 0 1.0243.4578 1.0243 1.0243 0 .5665-.4578 1.0242-1.0243 1.0242m-11.046 0c-.5665 0-1.0243-.4577-1.0243-1.0242 0-.5665.4578-1.0243 1.0243-1.0243.5665 0 1.0243.4578 1.0243 1.0243 0 .5665-.4578 1.0242-1.0243 1.0242m11.4045-6.02l2.0223-3.503a.416.416 0 0 0-.1521-.5676.416.416 0 0 0-.5677.1521l-2.0483 3.549C15.5902 8.2436 13.8533 7.8508 12 7.8508s-3.5902.3928-5.1367.9977L4.8151 5.3465a.4161.4161 0 0 0-.5677-.1521.4157.4157 0 0 0-.1521.5676l2.0223 3.503C2.6889 11.1868.3432 14.6589 0 18.761h24c-.3432-4.1021-2.6889-7.5742-6.1185-9.4396" fill="#43A047"/></svg>' +
    '<span style="color:#fff;font-weight:600;font-size:15px;">Download THE BAKERY Android App</span>' +
    '<a href="' + apkUrl + '" download style="background:#43A047;color:#fff;font-weight:700;font-size:14px;padding:9px 18px;border-radius:999px;text-decoration:none;">Download (v1.0)</a>';

  document.body.appendChild(bar);
})();
