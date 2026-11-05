'use strict'

function doGet(e = {}) {
  const action = (e.parameter && e.parameter.action) || 'dic'
  switch (action) {
    case 'tags':
      return getTags()
    case 'pron':
    case 'pronunciations':
      return getByPronunciations()
    case 'dic':
    case 'dictionary':
    default:
      return getDictionary()
  }
}

function getJSON (data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON)
}

// モロヘイヤのタグ辞書（related 形式）。旧 MAKOTO の MeCab 形式をやめるための出力
// （pooza/mulukhiya-toot-proxy#4880）。判定は MecabRemoteDictionary#parse を移したもの。
function getTags () {
  const sheet = SpreadsheetApp.getActiveSpreadsheet()
  const rows = sheet.getDataRange().getValues()
  const output = {}
  rows.forEach(row => {
    const classes = row.slice(4, 10)
    if (!classes.includes('固有名詞')) return
    if (classes.includes('姓') || classes.includes('名')) return
    output[row[0]] = []
  })
  return getJSON(output)
}

function getByPronunciations () {
  const sheet = SpreadsheetApp.getActiveSpreadsheet()
  // ⚠ このシートに見出しの行は無い。1 行目も語（捨てると pron.json から漏れる）。
  const rows = sheet.getDataRange().getValues()
  const convertKana = v => {
    return v
      .replace(/[\r\n\t\s]+/g, '')
      .replace(/[ぁ-ゖ]/g, match => String.fromCharCode(match.charCodeAt(0) + 0x60))
  }
  const fnv1a = v => {
    let h = 0x811c9dc5;
    for (let i = 0; i < v.length; i++) {
      h ^= v.charCodeAt(i);
      h = Math.imul(h, 0x01000193); // V8ランタイムで利用可
    }
    return (h >>> 0).toString(16);
  }
  const output = {}

  rows.map(row => {
    const item = {word: row[0], pronunciation: row[10]}
    if (!item.pronunciation) return
    item.word = item.word.replace(/(?<![!?])!(?![!?])/g, '！')
    item.pronunciation = convertKana(item.pronunciation)
    output[fnv1a(JSON.stringify(item))] = item
  })
  return getJSON(Object.values(output))
}

function getDictionary () {
  const sheet = SpreadsheetApp.getActiveSpreadsheet()
  const rows = sheet.getDataRange().getValues()
  const output = []
  rows.map(row => {
    const item = []
    row.map((val, i) => item.push(val))
    output.push(item)
  })
  return getJSON(output)
}
