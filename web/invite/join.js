(function () {
  var config = window.BeerCheersInviteConfig || {};
  var roomLine = document.getElementById("room-line");
  var statusEl = document.getElementById("status");
  var openApp = document.getElementById("open-app");
  var storeBtn = document.getElementById("store");
  var storeNote = document.getElementById("store-note");

  function roomIDFromPath() {
    var parts = window.location.pathname.split("/").filter(Boolean);
    // expected: join / <encoded-roomID>
    if (parts.length < 2 || parts[0] !== "join") return "";
    try {
      return decodeURIComponent(parts.slice(1).join("/")).trim();
    } catch (_) {
      return "";
    }
  }

  var roomID = roomIDFromPath();
  if (!roomID) {
    roomLine.textContent = "招待リンクが無効です。";
    statusEl.textContent = "URL の形式は /join/ルーム名 です。";
    openApp.hidden = true;
    return;
  }

  roomLine.textContent = "ルーム「" + roomID + "」への招待です。";

  var encoded = encodeURIComponent(roomID);
  var httpsJoin =
    window.location.origin + "/join/" + encoded;
  var customScheme = "beercheers://join/" + encoded;

  openApp.href = customScheme;
  openApp.addEventListener("click", function (event) {
    // Universal Link が効かない場合のフォールバックとしてカスタムスキームを試す。
    event.preventDefault();
    window.location.href = customScheme;
    statusEl.textContent =
      "アプリが開かない場合は、インストール後にもう一度このページを開いてください。";
  });

  // インストール済みなら HTTPS 自体がアプリに渡ることがある。
  // ブラウザで開いた場合は上のボタンでスキーム起動を試せる。
  statusEl.textContent =
    "アプリが入っている場合は「アプリで開く」をタップしてください。";

  var appStoreID = (config.appStoreID || "").trim();
  if (appStoreID) {
    storeBtn.hidden = false;
    storeBtn.href = "https://apps.apple.com/app/id" + appStoreID;
    storeNote.textContent = "アプリ未インストールの方は App Store から入手できます。";
  } else {
    storeBtn.hidden = true;
    storeNote.textContent =
      "App Store 公開後、ここからインストールできるようになります。公開まではインストール済みの端末でリンクを開いてください。";
  }

  // デバッグ用に現在の HTTPS 招待 URL を残す（画面には出さない）
  window.__beercheersInviteURL = httpsJoin;
})();
