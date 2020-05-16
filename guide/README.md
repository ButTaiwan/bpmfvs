# 讀音選擇工具

本規格提供有簡易網頁版[讀音選擇工具](https://buttaiwan.github.io/bpmfvs/)，輔助快速選擇讀音。

注意：使用線上版本，需先安裝[字嗨注音標楷](https://github.com/ButTaiwan/bpmfvs/releases/download/v1.100/BpmfZihiKaiStd.zip)字型。或是您可以下載[離線版讀音選擇工具](https://github.com/ButTaiwan/bpmfvs/releases/download/v1.100/Bpmf_VSIME.zip)在自己的機器上使用。

本讀音選擇工具使用「IVS」方式作為選擇讀音的方式。

1. 將想要加注音的文章貼到讀音選擇工具
	![Step1](ime-01.png?raw=true)

2. 按下 [開始] 以後，工具會自動將多音字加上底色。

	* 黃色：多音字
	* 紅色：多音字，已知本工具較不善於猜測的字
	* 橘色：多音字，且已經自動猜測讀音

	點選下方讀音選擇列的 ◀ ▶ 按鈕，可以移動到前/後一的多音字選擇讀音。也可以直接點擊想要修改的特定文字。
	![Step2](ime-02.png?raw=true)

3. 自行從下方讀音選擇列修改讀音的文字，會以綠色底顯示。
	![Step3](ime-03.png?raw=true)

4. 按下 [完成]，會回到原來的文字輸入狀態。並且整篇文章會被選取。
![Step4](ime-04.png?raw=true)
	
5. 右鍵 [複製]（或按 Ctrl+C / Cmd+C），並貼上到其他應用程式裡，可以看到選好的讀音都能正確複製過來。

	![Step5](ime-05.png?raw=true)

6. 更換字型（符合本注音字型規格者），讀音都不會跑掉。
	![Step6](ime-06.png?raw=true)

## 支援IVS方式的主要其他軟體

* Power Point
	![PowerPoint](ivs-01.png?raw=true)

* Photoshop CC

	請注意須確保 [偏好設定]→[文字]→[選擇文字引擎選項] 處為「拉丁和東亞版面」。

	※ 不同版本翻譯可能不同。設定後要從新檔案才會生效，或是需要重新開啟Photoshop。
	![Photoshop](ivs-02.png?raw=true)

* Illustrator CC

	請注意須確保 [偏好設定]→[文字]→[語言選項] 處為「顯示東亞選項」。

	※ 不同版本翻譯可能不同。設定後可能需要重新開啟Illustrator。
	![Illustrator](ivs-03.png?raw=true)

* InDesign CC

	請注意文字框的段落設定，應設定為「CJK段落視覺調整」或「CJK單行視覺調整」。

	![InDesign](ivs-04.png?raw=true)

## GSUB文體集選擇方式

**通常不建議使用，只有在軟體不支援IVS時作為替代方式**


本讀音選擇工具只支援使用IVS方式選擇讀音。
若使用不支援IVS的舊版應用程式，或只是需要一兩個字加注音，懶得開啟選擇工具時，也可以嘗試使用GSUB方式。

但請注意GSUB方式並無法確保複製到其他軟體時讀音還能保持一致。

### Word

* 可選取要選擇讀音的文字，開啟「字型」的「進階」分頁，從「文體集」裡的1、2、3…找到想要的讀音。
	![GSUB Word](gsub-wd-01.png?raw=true)

### Photoshop

* 開啟 [視窗]-[字符]，選取要選擇讀音的字後，從字符視窗中，按住要選擇讀音的字，從多個異體字裡找到想要選擇的讀音。
	![GSUB Photoshop](gsub-ps-01.png?raw=true)

### Illustrator

* (方法1) 在新的CC版本中，選取文字，就會直接出現浮動異體字選取框，可直接點選想要選擇的讀音。
	![GSUB Illustrator](gsub-ai-01.png?raw=true)

* (方法2) 選取要選擇讀音的字後，從「字符」視窗中找到想要選擇的讀音。
	![GSUB Illustrator](gsub-ai-02.png?raw=true)

* (方法3) 在「OpenType」視窗裡的「文體集」中，從集合1、集合2、集合3…找到想要的讀音。
	![GSUB Illustrator](gsub-ai-03.png?raw=true)

### InDesign

* (方法1) 在新的CC版本中，選取文字，就會直接出現浮動異體字選取框，可直接點選想要選擇的讀音。
	![GSUB InDesign](gsub-id-01.png?raw=true)

* (方法2) 選取要選擇讀音的字後，從「字符」視窗中找到想要選擇的讀音。
	![GSUB InDesign](gsub-id-02.png?raw=true)

* (方法3) 在「字元」視窗的「OpenType」→「文體集」中，從組合1、組合2、組合3…找到想要的讀音。
	![GSUB InDesign](gsub-id-03.png?raw=true)


## 備註

* 請[協助回報](https://github.com/ButTaiwan/bpmfvs/issues/1)較舊版本應用程式的支援情形。
