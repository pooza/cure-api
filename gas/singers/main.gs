'use strict'

function doGet(e = {}) {
  const action = (e.parameter && e.parameter.action) || 'singers'

  switch (action) {
    case 'index':
      return indexResponse()
    default:
      return singersResponse()
  }
}

function jsonOutput(data) {
  return ContentService.createTextOutput(JSON.stringify(data)).setMimeType(ContentService.MimeType.JSON)
}

function getSheetRows() {
  const sheet = SpreadsheetApp.getActiveSpreadsheet()
  const rows = sheet.getDataRange().getValues()
  const keys = rows.splice(0, 1)[0]
  return rows.map(row => {
    const item = {}
    row.map((val, i) => {
      item[keys[i]] = val
    })
    return item
  }).filter(item => String(item.name).trim() != '')
}

// カンマ区切りのセルを配列にする。空白と空要素は落とす。
function splitList(value) {
  if (!value) return []
  return String(value).split(',').map(v => v.trim()).filter(v => v != '')
}

function singersResponse() {
  const records = getSheetRows()
  const output = records.map(record => {
    return {
      name: String(record.name).trim(),
      members: splitList(record.members),
    }
  })
  return jsonOutput(output)
}

function indexResponse() {
  return jsonOutput(getSheetRows().map(record => String(record.name).trim()))
}
