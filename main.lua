require "import"
import "android.widget.*"
import "android.app.*"
import "android.view.*"
import "android.content.Context"
import "android.content.Intent"
import "android.net.Uri"
import "android.content.IntentFilter"
import "android.os.BatteryManager"
import "android.speech.tts.TextToSpeech"
import "android.net.wifi.WifiManager"
import "android.net.ConnectivityManager"
import "java.util.*"
import "java.text.SimpleDateFormat"
import "android.content.SharedPreferences"

local ctx = activity or service or this
local mainDialog = nil
local aboutDlg = nil
local tts = nil
local selectedTtsEngine = nil
local currentTtsName = "Default"

-- SharedPreferences for saving settings
local prefs = ctx.getSharedPreferences("AppSettings", Context.MODE_PRIVATE)
local editor = prefs.edit()

-- Load saved settings
local selectedLang = prefs.getString("selectedLang", "English")
local savedTtsEngine = prefs.getString("ttsEngine", nil)
if savedTtsEngine then
    selectedTtsEngine = savedTtsEngine
end

-- Language translations
local Lang = {
  English = {
    title="Information Announcer", 
    announce="Announce Battery Time", 
    wifi="Announce Wi-Fi Signal", 
    mobile="Announce Mobile Signal", 
    about="About", 
    goback="Go Back", 
    exit="Exit", 
    battery="Battery level is ", 
    percent=" percent", 
    its="It's ", 
    oclock=" o'clock ", 
    minutes=" minutes ", 
    today="Today is ", 
    year=" year ", 
    dev="Developer: Mohammed Rehan", 
    desc="This app announces Battery, Time, Date, Wi-Fi and Mobile Signal", 
    select="Select Language", 
    internetOff="Internet is off", 
    dataOff="Mobile data is off", 
    wifiSignal="Your Wi-Fi signal is ", 
    phoneSignal="Your phone signal is ", 
    bar=" bar", 
    ttsEngine="Select TTS Engine", 
    defaultTTS="Default", 
    close="Close",
    selectTTS="Select TTS Engine",
    langEnglish="English",
    langUrdu="Urdu",
    noWifi="Wi-Fi is not connected"
  },
  Urdu = {
    title="معلومات اعلان کنندہ", 
    announce="بیٹری اور وقت کا اعلان کریں", 
    wifi="وائی فائی سگنل کا اعلان کریں", 
    mobile="موبائل سگنل کا اعلان کریں", 
    about="تعارف", 
    goback="واپس جائیں", 
    exit="باہر جائیں", 
    battery="بیٹری لیول ہے ", 
    percent=" فیصد", 
    its="اب وقت ہے ", 
    oclock=" بجے ", 
    minutes=" منٹ ", 
    today="آج ہے ", 
    year=" سال ", 
    dev="ڈویلپر: محمد ریحان", 
    desc="یہ ایپ بیٹری، وقت، تاریخ، وائی فائی اور موبائل سگنل کا اعلان کرتی ہے", 
    select="زبان منتخب کریں", 
    internetOff="انٹرنیٹ بند ہے", 
    dataOff="موبائل ڈیٹا بند ہے", 
    wifiSignal="آپ کے وائی فائی کا سگنل ", 
    phoneSignal="آپ کے فون کا سگنل ", 
    bar=" بار ہے", 
    ttsEngine="ٹی ٹی ایس انجن منتخب کریں", 
    defaultTTS="ڈیفالٹ", 
    close="بند کریں",
    selectTTS="ٹی ٹی ایس انجن منتخب کریں",
    langEnglish="انگریزی",
    langUrdu="اردو",
    noWifi="وائی فائی منسلک نہیں ہے"
  }
}

-- Urdu numbers with proper words
local function numToWords(n, lang)
  local en = {"zero","one","two","three","four","five"}
  local ur = {"صفر","ایک","دو","تین","چار","پانچ"}
  if lang == "Urdu" then 
    if n >= 0 and n <= 5 then
      return ur[n+1] or tostring(n)
    else
      return tostring(n)
    end
  else 
    if n >= 0 and n <= 5 then
      return en[n+1] or tostring(n)
    else
      return tostring(n)
    end
  end
end

local function closeAllAndOpen(url)
  if aboutDlg then aboutDlg.dismiss() end
  if mainDialog then mainDialog.dismiss() end
  local intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
  ctx.startActivity(intent)
end

local function openWhatsAppGroup()
  local message = "Hello Assalamualaikum! I am Aftab Ali. Please add me to CSR Expert WhatsApp Group. Thank you!"
  local url = "https://wa.me/923425037026?text="..Uri.encode(message)
  closeAllAndOpen(url)
end

local function openLink(url)
  closeAllAndOpen(url)
end

local function initTTS(engine)
  if tts then 
    tts.shutdown() 
    tts = nil
  end
  
  if engine then
    tts = TextToSpeech(ctx, function(status)
      if status == TextToSpeech.SUCCESS then
        tts.setLanguage(Locale.getDefault())
      end
    end, engine)
  else
    tts = TextToSpeech(ctx, function(status)
      if status == TextToSpeech.SUCCESS then
        tts.setLanguage(Locale.getDefault())
      end
    end)
  end
end

local function speak(text)
  if not tts then 
    initTTS(selectedTtsEngine) 
    local wait = 0
    while tts == nil and wait < 10 do
      Thread.sleep(100)
      wait = wait + 1
    end
  end
  if tts then
    pcall(function() 
      tts.speak(text, TextToSpeech.QUEUE_FLUSH, nil) 
    end)
  end
end

local function getBatteryLevel()
  local bm = ctx.registerReceiver(nil, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
  local level = bm.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
  local scale = bm.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
  return math.floor(level * 100 / scale)
end

local function announceWifiSignal()
  local L = Lang[selectedLang]
  local cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE)
  local networkInfo = cm.getNetworkInfo(ConnectivityManager.TYPE_WIFI)

  if networkInfo == nil or not networkInfo.isConnected() then
    speak(L.noWifi)
    return
  end

  local wifiManager = ctx.getSystemService(Context.WIFI_SERVICE)
  local wifiInfo = wifiManager.getConnectionInfo()
  local rssi = wifiInfo.getRssi()
  local level = WifiManager.calculateSignalLevel(rssi, 5)
  
  -- Convert level to words in selected language
  local levelWord = numToWords(level, selectedLang)
  
  -- Create announcement text in proper language
  local text
  if selectedLang == "Urdu" then
    text = L.wifiSignal .. levelWord .. L.bar
  else
    text = L.wifiSignal .. levelWord .. L.bar
  end
  
  speak(text)
end

local function announceMobileSignal()
  local L = Lang[selectedLang]
  local cm = ctx.getSystemService(Context.CONNECTIVITY_SERVICE)
  local networkInfo = cm.getNetworkInfo(ConnectivityManager.TYPE_MOBILE)

  if networkInfo == nil or not networkInfo.isConnected() then
    speak(L.dataOff)
    return
  end

  local signalStrength = 3
  local levelWord = numToWords(signalStrength, selectedLang)
  
  local text
  if selectedLang == "Urdu" then
    text = L.phoneSignal .. levelWord .. L.bar
  else
    text = L.phoneSignal .. levelWord .. L.bar
  end
  
  speak(text)
end

local function announceAll()
  local L = Lang[selectedLang]
  local battery = getBatteryLevel()
  local cal = Calendar.getInstance()
  local hour = cal.get(Calendar.HOUR_OF_DAY)
  local minute = cal.get(Calendar.MINUTE)
  local dayName = SimpleDateFormat("EEEE").format(cal.getTime())
  local monthName = SimpleDateFormat("MMMM").format(cal.getTime())
  local dayNum = cal.get(Calendar.DAY_OF_MONTH)
  local yearNum = cal.get(Calendar.YEAR)

  local ampm = "AM"
  if hour >= 12 then ampm = "PM" end
  hour = hour % 12
  if hour == 0 then hour = 12 end

  local batteryText = L.battery.. tostring(battery).. L.percent
  local timeText = L.its.. tostring(hour).. L.oclock.. tostring(minute).. L.minutes.. ampm
  local dateText = L.today.. dayName..", ".. tostring(dayNum).." ".. monthName.. L.year.. tostring(yearNum)
  local finalText = batteryText.. ". ".. timeText.. ". ".. dateText
  
  speak(finalText)
end

local function showAbout()
  local L = Lang[selectedLang]
  aboutDlg = LuaDialog(ctx)
  aboutDlg.setTitle(L.about)
  local scroll = ScrollView(ctx)
  local layout = LinearLayout(ctx)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(30,30,30,30)

  local txt = TextView(ctx)
  -- About text in selected language
  local aboutText
  if selectedLang == "Urdu" then
    aboutText = "معلومات اعلان کنندہ\nورژن: 1.5\n"..L.dev.."\n\n"..L.desc.."\n\nہمارے ساتھ شامل ہوں:"
  else
    aboutText = L.title.."\nVersion: 1.5\n"..L.dev.."\n\n"..L.desc.."\n\nJoin Us:"
  end
  txt.setText(aboutText)
  txt.setTextSize(16)
  txt.setPadding(0,0,0,20)
  layout.addView(txt)

  local btnGroup = Button(ctx)
  if selectedLang == "Urdu" then
    btnGroup.setText("واٹس ایپ گروپ میں شامل ہوں")
  else
    btnGroup.setText("Join WhatsApp Group")
  end
  btnGroup.setOnClickListener(function() openWhatsAppGroup() end)
  layout.addView(btnGroup)

  local btnCSR = Button(ctx)
  if selectedLang == "Urdu" then
    btnCSR.setText("واٹس ایپ پر CSR Expert کو فالو کریں")
  else
    btnCSR.setText("Follow CSR Expert on WhatsApp")
  end
  btnCSR.setOnClickListener(function() openLink("https://whatsapp.com/channel/0029VbCfIq3Fi8xXRpRxqP1B") end)
  layout.addView(btnCSR)

  local btnATV = Button(ctx)
  if selectedLang == "Urdu" then
    btnATV.setText("واٹس ایپ پر Accessible Tech Vision کو فالو کریں")
  else
    btnATV.setText("Follow Accessible Tech Vision on WhatsApp")
  end
  btnATV.setOnClickListener(function() openLink("https://whatsapp.com/channel/0029Vb7IpqF23n3oxCl4ts25") end)
  layout.addView(btnATV)

  local btnYT1 = Button(ctx)
  if selectedLang == "Urdu" then
    btnYT1.setText("یوٹیوب پر CSR Expert کو سبسکرائب کریں")
  else
    btnYT1.setText("Subscribe CSR Expert on YouTube")
  end
  btnYT1.setOnClickListener(function() openLink("https://youtube.com/@csrexpert-d5v?si=xi-Ch7BYEzpJ5bTq") end)
  layout.addView(btnYT1)

  local btnYT2 = Button(ctx)
  if selectedLang == "Urdu" then
    btnYT2.setText("یوٹیوب پر Accessible Tech Vision کو سبسکرائب کریں")
  else
    btnYT2.setText("Subscribe Accessible Tech Vision on YouTube")
  end
  btnYT2.setOnClickListener(function() openLink("https://youtube.com/@accessibletechvision?si=weUuoOLZLCzD53fu") end)
  layout.addView(btnYT2)

  local btnGoBack = Button(ctx)
  btnGoBack.setText(L.goback)
  btnGoBack.setOnClickListener(function() aboutDlg.dismiss() end)
  layout.addView(btnGoBack)

  scroll.addView(layout)
  aboutDlg.setView(scroll)
  aboutDlg.show()
end

local function getInstalledTtsEngines()
  local engines = {}
  local pm = ctx.getPackageManager()
  local intent = Intent(TextToSpeech.Engine.INTENT_ACTION_TTS_SERVICE)
  local list = pm.queryIntentServices(intent, 0)
  
  for i = 0, list.size() - 1 do
    local info = list.get(i)
    local packageName = info.serviceInfo.packageName
    local label = info.loadLabel(pm)
    if label then
      table.insert(engines, {name = tostring(label), package = packageName})
    else
      table.insert(engines, {name = packageName, package = packageName})
    end
  end
  return engines
end

local function selectTtsEngine()
  local L = Lang[selectedLang]
  local ttsDlg = LuaDialog(ctx)
  ttsDlg.setTitle(L.selectTTS)
  ttsDlg.setCancelable(false)
  
  local scroll = ScrollView(ctx)
  local layout = LinearLayout(ctx)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(30,30,30,30)
  
  local heading = TextView(ctx)
  heading.setText(L.selectTTS)
  heading.setTextSize(20)
  heading.setGravity(Gravity.CENTER)
  heading.setPadding(0,0,0,20)
  heading.setTextColor(0xFF2196F3)
  layout.addView(heading)
  
  local sep = View(ctx)
  sep.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 2))
  sep.setBackgroundColor(0xFF2196F3)
  layout.addView(sep)
  
  local engines = getInstalledTtsEngines()
  
  if #engines == 0 then
    local txt = TextView(ctx)
    txt.setText("No TTS engines found")
    txt.setTextSize(18)
    txt.setGravity(Gravity.CENTER)
    txt.setPadding(0,30,0,30)
    layout.addView(txt)
  else
    for i,v in ipairs(engines) do
      local btn = Button(ctx)
      local displayName = v.name
      local isSelected = (selectedTtsEngine == v.package)
      
      if isSelected then
        displayName = "Selected: " .. displayName
        btn.setBackgroundColor(0xFF4CAF50)
        btn.setTextColor(0xFFFFFFFF)
      else
        displayName = " " .. displayName
        btn.setBackgroundColor(0xFFE0E0E0)
        btn.setTextColor(0xFF000000)
      end
      
      btn.setText(displayName)
      btn.setTextSize(16)
      btn.setPadding(20,15,20,15)
      
      local params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
      params.setMargins(0,5,0,5)
      btn.setLayoutParams(params)
      
      btn.setOnClickListener(function()
        selectedTtsEngine = v.package
        currentTtsName = v.name
        editor.putString("ttsEngine", selectedTtsEngine)
        editor.apply()
        ttsDlg.dismiss()
        initTTS(selectedTtsEngine)
        speak("TTS engine changed to "..v.name)
      end)
      layout.addView(btn)
    end
  end
  
  local isDefaultSelected = (selectedTtsEngine == nil)
  local btnDefault = Button(ctx)
  local defaultText = L.defaultTTS
  if isDefaultSelected then
    defaultText = "Selected: " .. L.defaultTTS
    btnDefault.setBackgroundColor(0xFF4CAF50)
    btnDefault.setTextColor(0xFFFFFFFF)
  else
    defaultText = " " .. L.defaultTTS
    btnDefault.setBackgroundColor(0xFFE0E0E0)
    btnDefault.setTextColor(0xFF000000)
  end
  btnDefault.setText(defaultText)
  btnDefault.setTextSize(16)
  btnDefault.setPadding(20,15,20,15)
  
  local params = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT)
  params.setMargins(0,5,0,5)
  btnDefault.setLayoutParams(params)
  
  btnDefault.setOnClickListener(function()
    selectedTtsEngine = nil
    currentTtsName = L.defaultTTS
    editor.remove("ttsEngine")
    editor.apply()
    ttsDlg.dismiss()
    initTTS()
    speak(L.defaultTTS.." TTS engine selected")
  end)
  layout.addView(btnDefault)
  
  local sep2 = View(ctx)
  sep2.setLayoutParams(LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 2))
  sep2.setBackgroundColor(0xFF9E9E9E)
  sep2.setPadding(0,10,0,10)
  layout.addView(sep2)
  
  local info = TextView(ctx)
  local currentText = "Current TTS: "
  if selectedTtsEngine then
    currentText = currentText .. currentTtsName
  else
    currentText = currentText .. L.defaultTTS
  end
  info.setText(currentText)
  info.setTextSize(14)
  info.setGravity(Gravity.CENTER)
  info.setPadding(0,10,0,10)
  info.setTextColor(0xFF2196F3)
  layout.addView(info)
  
  local btnClose = Button(ctx)
  btnClose.setText(L.close)
  btnClose.setTextSize(16)
  btnClose.setPadding(20,15,20,15)
  btnClose.setOnClickListener(function() 
    ttsDlg.dismiss() 
  end)
  layout.addView(btnClose)
  
  scroll.addView(layout)
  ttsDlg.setView(scroll)
  ttsDlg.show()
end

local function selectLanguage()
  local langDlg = LuaDialog(ctx)
  langDlg.setTitle(Lang[selectedLang].select)
  langDlg.setCancelable(false)
  local layout = LinearLayout(ctx)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(20,20,20,20)
  
  -- English option
  local btnEnglish = Button(ctx)
  local englishText = Lang[selectedLang].langEnglish
  if selectedLang == "English" then
    englishText = englishText .. " 鉁?"
    btnEnglish.setBackgroundColor(0xFF4CAF50)
    btnEnglish.setTextColor(0xFFFFFFFF)
  else
    btnEnglish.setBackgroundColor(0xFFE0E0E0)
    btnEnglish.setTextColor(0xFF000000)
  end
  btnEnglish.setText(englishText)
  btnEnglish.setTextSize(16)
  btnEnglish.setPadding(20,15,20,15)
  btnEnglish.setOnClickListener(function()
    if selectedLang ~= "English" then
      selectedLang = "English"
      editor.putString("selectedLang", selectedLang)
      editor.apply()
      langDlg.dismiss()
      if mainDialog then mainDialog.dismiss() end
      openApp()
    else
      langDlg.dismiss()
    end
  end)
  layout.addView(btnEnglish)
  
  -- Urdu option
  local btnUrdu = Button(ctx)
  local urduText = Lang[selectedLang].langUrdu
  if selectedLang == "Urdu" then
    urduText = urduText .. " 鉁?"
    btnUrdu.setBackgroundColor(0xFF4CAF50)
    btnUrdu.setTextColor(0xFFFFFFFF)
  else
    btnUrdu.setBackgroundColor(0xFFE0E0E0)
    btnUrdu.setTextColor(0xFF000000)
  end
  btnUrdu.setText(urduText)
  btnUrdu.setTextSize(16)
  btnUrdu.setPadding(20,15,20,15)
  btnUrdu.setOnClickListener(function()
    if selectedLang ~= "Urdu" then
      selectedLang = "Urdu"
      editor.putString("selectedLang", selectedLang)
      editor.apply()
      langDlg.dismiss()
      if mainDialog then mainDialog.dismiss() end
      openApp()
    else
      langDlg.dismiss()
    end
  end)
  layout.addView(btnUrdu)
  
  local btnClose = Button(ctx)
  btnClose.setText(Lang[selectedLang].close)
  btnClose.setTextSize(16)
  btnClose.setPadding(20,15,20,15)
  btnClose.setOnClickListener(function()
    langDlg.dismiss()
  end)
  layout.addView(btnClose)
  
  langDlg.setView(layout)
  langDlg.show()
end

function openApp()
  if mainDialog then mainDialog.dismiss() end
  local L = Lang[selectedLang]
  mainDialog = LuaDialog(ctx)
  mainDialog.setTitle(L.title)
  mainDialog.setCancelable(false)
  
  local layout = LinearLayout(ctx)
  layout.setOrientation(LinearLayout.VERTICAL)
  layout.setPadding(40,40,40,40)

  local btnAnnounce = Button(ctx)
  btnAnnounce.setText(L.announce)
  btnAnnounce.setTextSize(16)
  btnAnnounce.setPadding(20,15,20,15)
  btnAnnounce.setOnClickListener(function() announceAll() end)
  layout.addView(btnAnnounce)

  local btnWifi = Button(ctx)
  btnWifi.setText(L.wifi)
  btnWifi.setTextSize(16)
  btnWifi.setPadding(20,15,20,15)
  btnWifi.setOnClickListener(function() announceWifiSignal() end)
  layout.addView(btnWifi)

  local btnMobile = Button(ctx)
  btnMobile.setText(L.mobile)
  btnMobile.setTextSize(16)
  btnMobile.setPadding(20,15,20,15)
  btnMobile.setOnClickListener(function() announceMobileSignal() end)
  layout.addView(btnMobile)

  local btnLang = Button(ctx)
  btnLang.setText(L.select)
  btnLang.setTextSize(16)
  btnLang.setPadding(20,15,20,15)
  btnLang.setOnClickListener(function() selectLanguage() end)
  layout.addView(btnLang)
  
  local btnTts = Button(ctx)
  btnTts.setText(L.ttsEngine)
  btnTts.setTextSize(16)
  btnTts.setPadding(20,15,20,15)
  btnTts.setOnClickListener(function() selectTtsEngine() end)
  layout.addView(btnTts)

  local btnAbout = Button(ctx)
  btnAbout.setText(L.about)
  btnAbout.setTextSize(16)
  btnAbout.setPadding(20,15,20,15)
  btnAbout.setOnClickListener(function() showAbout() end)
  layout.addView(btnAbout)

  local btnClose = Button(ctx)
  btnClose.setText(L.exit)
  btnClose.setTextSize(16)
  btnClose.setPadding(20,15,20,15)
  btnClose.setOnClickListener(function()
    if mainDialog then mainDialog.dismiss() end
    if tts then tts.shutdown() end
    mainDialog = nil
  end)
  layout.addView(btnClose)

  mainDialog.setView(layout)
  mainDialog.show()
end

-- Initialize with saved settings
initTTS(selectedTtsEngine)
openApp()