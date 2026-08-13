'use strict'

// ⚠ シート名で取る。**スプレッドシートの 1 枚目とは限らない**ので
// `getActiveSpreadsheet().getDataRange()`（＝アクティブシート依存）にしない。
const SHEET_NAME = '歌手'

function doGet(e = {}) {
  const action = (e.parameter && e.parameter.action) || 'aliases'

  switch (action) {
    case 'singers':
      return singersResponse()
    case 'index':
      return indexResponse()
    default:
      return aliasesResponse()
  }
}

function jsonOutput(data) {
  return ContentService.createTextOutput(JSON.stringify(data)).setMimeType(ContentService.MimeType.JSON)
}

function getSheetRows() {
  const sheet = SpreadsheetApp.getActive().getSheetByName(SHEET_NAME)
  // ⚠ シートが無いことを黙って「0 件」にしない。名前を変えたら気付けるようにする。
  if (!sheet) throw new Error('sheet "' + SHEET_NAME + '" not found')
  const rows = sheet.getDataRange().getValues()
  const keys = rows.splice(0, 1)[0]
  return rows.map(row => {
    const item = {}
    row.map((val, i) => {
      item[String(keys[i])] = val
    })
    return item
  }).filter(item => String(item.name).trim() != '')
}

// カンマ区切りのセルを配列にする。空白と空要素は落とす。
function splitList(value) {
  if (!value) return []
  return String(value).split(',').map(v => v.trim()).filter(v => v != '')
}

// ⚠⚠ **パラメータ無しの応答は変えない（既存互換）。**`{名義: [構成員]}` の
// マップを返していた旧実装が、既にデプロイされて動いている。⚠ 利用者が
// リポジトリ内に見つからなくても、形を変えれば黙って壊れる先がありうる。
// girls / series も同じ理由でパラメータ無しを旧形式のまま残している。
function aliasesResponse() {
  const output = {}
  getSheetRows().map(item => {
    output[String(item.name).trim()] = splitList(item.members)
  })
  return jsonOutput(output)
}

// cure-api の /singers が引く形。⚠ 名義の順をスプレッドシートの並びのまま保つ
// （マップだと順序を当てにできない）。
function singersResponse() {
  return jsonOutput(getSheetRows().map(record => {
    return {
      name: String(record.name).trim(),
      members: splitList(record.members),
    }
  }))
}

function indexResponse() {
  return jsonOutput(getSheetRows().map(record => String(record.name).trim()))
}
