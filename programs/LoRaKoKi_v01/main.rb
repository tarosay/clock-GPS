#!mruby
#V2.53
# AE-AQM1602XA-RN-GBW
ADD = 0x3E
Lcd = I2c.new(0)
Usb = Serial.new(0)
LoRa = Serial.new(1,115200)
Sw0 = 4
Sw1 = 3
CntRead = 0
RFile = "message.txt"
Title0 = "Kushimoto Ver1.0"
Title1 = "by Team DangoSat"

pinMode(Sw0, INPUT)
pinMode(Sw1, INPUT)

while(Usb.available > 0)do	#USBのシリアルバッファクリア
  Usb.read
end
while(LoRa.available > 0)do  #LoRa側のシリアルバッファクリア
  LoRa.read
end

#液晶へ１コマンド出力
def lcd_cmd(cmd)
    Lcd.write(ADD,0x00,cmd)

    if((cmd == 0x01)||(cmd == 0x02))then
        delay(2)
    else
        delay 0
    end
end

#データを送る
def lcd_data(dat)
    Lcd.write(ADD,0x40,dat)
    delay 0
end

#カーソルのセット
def lcd_setCursor(clm,row)
    if(row==0)then
        lcd_cmd(0x80+clm)
    end
    
    if(row==1)then
        lcd_cmd(0xc0+clm)
    end
end

#LCDの初期化
def lcd_begin()
    #puts "lcd_begin"
    delay 100
    lcd_cmd(0x38)   #// 8bit 2line Normal mode
    lcd_cmd(0x39)   #// 8bit 2line Extend mode
    lcd_cmd(0x14)   #// OSC 183Hz BIAS 1/5

    #/* コントラスト設定 */
    contrast = 0x5F
    lcd_cmd(0x70 + (contrast & 0x0F))   #//下位4bit
    lcd_cmd(0x5C + ((contrast >> 4)& 0x3))     #//上位2bit
    #lcd_cmd(0x6B)                   #// Follwer for 3.3V
    lcd_cmd(0x6C)                   #// Follwer for 3.3V
    delay(300)

    lcd_cmd(0x38)       #// Set Normal mode
    lcd_cmd(0x0C)       #// Display On
    lcd_cmd(0x01)       #// Clear Display
    delay(2)
    
    #puts "end of lcd_begin"
end

#//全消去関数
def lcd_clear()
    lcd_cmd(0x01)   #//初期化コマンド出力
    delay(2)
end

#//文字列表示関数
def lcd_print(cs)
    cs.each_byte{|c| lcd_data(c)}
end
####
#タイトルの表示
def dispTitle()
  lcd_setCursor(0,0)  #カーソルを0行に位置設定
  lcd_print Title0
  lcd_setCursor(0,1)  #カーソルを0行に位置設定
  lcd_print Title1
end

def rtc_init()
  tm1 = Rtc.getTime
  delay 1100
  tm2 = Rtc.getTime

  if(tm1[5] == tm2[5] || tm1[0] < 2010)then
      puts 'RTC Initialized'
      Rtc.init
      Rtc.setTime([2020,9,15,4,34,0])
  end
end

def zeroAdd(num)
  str = "00" + num.to_s
  str[str.length-2..str.length]
end

#puts "Input Date and time. Example:"
#     #0123456789012345678
#puts "2020/09/15 05:24:00;"
#puts "-------------------"
def commandRead()
  readbuff = "#"
  command_get = 0
  cnt = 0
  loop do
    while(Usb.available() > 0) do #何か受信があったらreadbuffに蓄える
      a = Usb.read()
      readbuff += a
      Usb.print a
      if a.to_s == ";" then
        command_get = 1
        break
      end
      delay 20
      cnt = 0
    end #while

    if readbuff.length > 0 then
      cnt += 1
      if cnt > 500 then
        command_get = 1
        break
      end      
      delay 20
    end    

    if command_get==1 || readbuff=="" then
      break
    end
  end #loop

  if command_get==1 then
    command_get = 0
    if(readbuff[5]=="/" and readbuff[8]=="/" and readbuff[11]==" " and readbuff[14]==":" and readbuff[17]==":")then
      if(readbuff.length >= 19 )then
        year = readbuff[1,4].to_i
        mon	 = readbuff[6,2].to_i
        da	 = readbuff[9,2].to_i
        ho	 = readbuff[12,2].to_i
        min	 = readbuff[15,2].to_i
        sec	 = readbuff[18,2].to_i
        Rtc.deinit()
        #Rtc.init(-20)	# RTC補正：10 秒毎に 20/32768 秒遅らせる
        Rtc.init()      # v2.83以降：デフォルト値(-20)で補正を行う
        Rtc.setTime([year,mon,da,ho,min,sec])
      end
      year,mon,da,ho,min,sec = Rtc.getTime()
      puts ""
      puts year.to_s + "/" + zeroAdd(mon) + "/" + zeroAdd(da) + " " + zeroAdd(ho) + ":" + zeroAdd(min) + ":" + zeroAdd(sec)
      puts "RTC setteing is done."
    else
      puts ""
      puts "Illegal command:" + readbuff
      readbuff = ""
    end #if
  end
end

#####
#時計の表示
#####
def dispTime()
  year,mon,da,ho,min,sec = Rtc.getTime
  body = "'" + zeroAdd(year-2000) + "/" + zeroAdd(mon) + "/" + zeroAdd(da)
  if((sec % 2)==0)then
    c=" "
    led 0
  else
    c=":"
    led 1
  end
  body += " " + zeroAdd(ho) + c + zeroAdd(min) + " "

  if(Last_sec != sec) then
    Last_sec = sec
    lcd_setCursor(0,0)      #カーソルを0行に位置設定
    lcd_print(body)    #文字列表示
    #puts body
    #lcd_setCursor(0,1)      #カーソルを0行に位置設定
    #lcd_print(zeroAdd(sec))    #文字列表示
  end
end
###
#LoRa通信の初期化
def initLoRa()
  c = "2\r\n"
  LoRa.write c, c.length
  delay 500
  c = "z\r\n"
  LoRa.write c, c.length
  delay 500
end
####
#スクロール表示
def disp2(txt)
  d = ""
  for i in 0..(txt.length - 1)
    if(txt.bytes[i] != 0x0d && txt.bytes[i] != 0x0a)then
      d += txt[i]
    end
  end
  if(d.length < 16)then
    d += "                "
    d = d[0..15]
    lcd_setCursor(0,1)  #カーソルを0行に位置設定
    lcd_print d
    return
  end
  txt = d
  d = d[0..15]
  lcd_setCursor(0,1)  #カーソルを0行に位置設定
  lcd_print d
  delay 300
  for i in 16..(txt.length - 1)
    for x in 0..14
      d[x] = d[x + 1]
    end
    d[15] = txt[i]
    lcd_setCursor(0,1)  #カーソルを0行に位置設定
    lcd_print d
    #puts d
    delay 300
  end
end
####
#SW0ボタンを押した
def sw0_Push
  lcd_setCursor(0,1)      #カーソルを0行に位置設定
  lcd_print "                "
  tm = Rtc.getTime
  c = "K1>"
  c += zeroAdd(tm[1]) + "/" + zeroAdd(tm[2])
  c += " " + zeroAdd(tm[3]) + ":" +zeroAdd(tm[4]) + ":" +zeroAdd(tm[5])
  d = c + "\r\n"
  LoRa.write d, d.length 
  delay 1000
  disp2 c
end
###
#返ってきた文字列を保存
def saveTxt(txt)
  if(txt[0] == "\r" || txt[0] == "\n")then
    return
  end
  tm = Rtc.getTime
  c = zeroAdd(tm[0]) + "/" + zeroAdd(tm[1]) + "/" + zeroAdd(tm[2])
  c += " " + zeroAdd(tm[3]) + ":" +zeroAdd(tm[4])
  txt = c + ">" + txt
  MemFile.open(0,RFile,1)
  MemFile.write(0,txt,txt.length)
  MemFile.close(0)
end
###
#sw1ボタンを押した
def sw1_Push()
  MemFile.open(0,RFile,0)
  i = 0
  j = 0
  acnt = []
  loop do
    c = MemFile.read(0)
    if(c < 0)then
      break
    end
    if(c == 0x0a)then
      acnt[i] = j
      i += 1
    end
    j += 1
  end
  #puts "CntRead=" + CntRead.to_s
  #for i in 0..i-1
  #  puts acnt[i]
  #end
  a = acnt.length - 2 - CntRead
  if(a < 0)then
    if(acnt.length > 0 && a == -1)then
      MemFile.seek(0, 0)
      t = ""
      for i in 0..(acnt[0] - 1)
        c = MemFile.read(0)
        t += c.chr
      end
      disp2 t
      CntRead += 1
    else
      disp2 "log end."
      CntRead = 0
    end
  else
    MemFile.seek(0, acnt[a])
    t = ""
    for i in 0..(acnt[a + 1] - acnt[a] - 1)
      c = MemFile.read(0)
      t += c.chr
    end
    disp2 t
    CntRead += 1
  end   
  MemFile.close(0)
end

rtc_init
lcd_begin   #初期設定
dispTitle   #タイトルの表示 
initLoRa    #LoRa通信の初期化
delay 4000
lcd_clear   #全消去

Last_sec = 0    #前の秒カウント値
lines = ""
sw = [0,0,0]
loop do

  while(Usb.available() > 0) do
    a = Usb.read()
    if a.to_s == "#" then
      commandRead
    end
  end #while

  dispTime  #時計の表示 

  while(LoRa.available() > 0) do
    c = LoRa.read()
    for i in 0..(c.length - 1)
      lines = lines + c.bytes[i].chr
      if(c.bytes[i] == 0x0A)then
        #puts lines
        disp2 lines     #文字列表示
        if(lines[0] == "O" && lines[1] == "K")then
          #OKのときは何もしない
        elsif(lines[0] == "N" && lines[1] == "G")then
            #NGのときは何もしない
        else
          #返ってきた文字列を保存
          saveTxt lines
        end
        lines = ""
        GC.start
      end
    end
  end
  
  swn = digitalRead(Sw1) * 2 + digitalRead(Sw0)
  if swn == 3 then
    sw[0] = 0
    sw[1] = 0
    sw[2] = 0
    #lcd_setCursor(0,1)  #カーソルを0行に位置設定
    #lcd_print "       "
  elsif swn ==2 && (sw[0] == 0 || sw[2] == 1)then
    sw[0] = 1
    sw[1] = 0
    sw[2] = 0
    sw0_Push
    CntRead = 0
    #lcd_setCursor(0,1)  #カーソルを0行に位置設定
    #lcd_print "SW0    "
  elsif swn ==1 && (sw[1] == 0 || sw[2] == 1)then
    sw[0] = 0
    sw[1] = 1
    sw[2] = 0
    sw1_Push
    #lcd_setCursor(0,1)  #カーソルを0行に位置設定
    #lcd_print "SW1    "
  elsif (swn ==0 && sw[0] == 0) then
    sw[0] = 1
    sw[2] = 1
    #lcd_setCursor(0,1)  #カーソルを0行に位置設定
    #lcd_print "SW1 SW0"
    MemFile.rm RFile
    dispTitle #タイトルの表示 
    delay 5000
    CntRead = 0
  elsif (swn ==0 && sw[1] == 0) then
    sw[1] = 1
    sw[2] = 1
    #lcd_setCursor(0,1)  #カーソルを0行に位置設定
    #lcd_print "SW0 SW1"
    MemFile.rm RFile
    dispTitle #タイトルの表示 
    delay 5000
    CntRead = 0
  end

  delay 10
end #loop
#System.exit()
