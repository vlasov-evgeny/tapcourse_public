require 'google_drive'

# Класс для взаимодействия с GoogleDrive.
# Для работы класса следуют выполнить действия описанные по ссылке:
# https://github.com/gimite/google-drive-ruby/blob/master/doc/authorization.md#service-account
#
# Example:
#
#   service_account_key = 'path/to/service_account_key.json'
#   spreadsheet_key = 'my-spreadsheet-key'
#
#   g = GoogleDriveApi.new(service_account_key, spreadsheet_key)
#
#   title_row = ['column1', 'column2'] # Row 1
#   rows = [
#     ['value1', 'value2'], # Row 2
#     ['value3', 'value4']  # Row 3
#   ]
#
#   g.insert_row(title_row)
#   g.insert_rows(rows)
#
class GoogleDriveApi
  attr_writer :worksheet_num

  # Инициализиатор объекта класса.
  # @param service_account_key [String]: Путь к JSON-файлу, полученному с GoogleDrive для серивисного аккаунта.
  # @param spreadsheet_key [String]: Идентификатор файла, с которым нужно взаимодейстовавать.
  # @param id_column_name [String]: Названиние колонки, где хранится идентификатор записи (нужно для поиска)
  def initialize(service_account_key, spreadsheet_key, id_column_name = 'ID')
    @service_account_key_json = service_account_key
    @spreadsheet_key = spreadsheet_key
    @id_column_name = id_column_name
    @worksheet_num = 0
    @worksheets = nil
  end

  def insert_rows(rows, row_num = nil)
    row_num ||= worksheet.num_rows + 1
    worksheet.insert_rows(row_num, rows)
  end

  def insert_rows!(rows, row_num = nil)
    build_session
    insert_rows(rows, row_num)
    worksheet.save
  end

  def insert_row(row, row_num = nil)
    insert_rows([row], row_num)
  end

  def insert_row!(row, row_num = nil)
    insert_rows!([row], row_num)
  end

  def delete_rows(row_num, rows)
    worksheet.delete_rows(row_num, rows)
  end

  def delete_rows!(row_num, rows)
    build_session
    delete_rows(row_num, rows)
    worksheet.save
  end

  def delete_row(row_num)
    delete_rows(row_num, 1)
  end

  def delete_row!(row_num)
    delete_rows!(row_num, 1)
  end

  def update_row!(row, row_num)
    worksheet.update_cells(row_num, 1, [row])
    worksheet.save
  end

  def update_row_by_id!(row, id, id_column_name = nil)
    build_session
    row_num = find_row_num_by_id(id, id_column_name || @id_column_name)
    update_row!(row, row_num) unless row_num.nil?
  end

  def update_or_insert_row_by_id!(row, id, id_column_name = nil)
    row_num = find_row_num_by_id(id, id_column_name || @id_column_name)
    if row_num.nil?
      insert_row!(row)
    else
      update_row!(row, row_num)
    end
  end

  def delete_row_by_id!(id, id_column_name = nil)
    row_num = find_row_num_by_id(id, id_column_name || @id_column_name)
    delete_row!(row_num) unless row_num.nil?
  end

  def reset_worksheets
    @worksheets.each { |ws| ws.delete_rows(2, ws.max_rows - 1)}
  end

  def reset_worksheets!(header = nil)
    build_session
    @worksheets.each do |ws|
      ws.delete_rows(2, ws.max_rows - 1)
      ws.save
      if header.present?
        ws.update_cells(1, 1, [header])
        ws.save
      end
    end
  end

  def save_worksheets!
    @worksheets.map(&:save)
  end

  def find_row_num_by_id(id, id_column_name = nil)
    column_name = (id_column_name || @id_column_name).to_s
    worksheet.list.each_with_index do |row, index|
      next unless row[column_name].to_s == id.to_s
      return index + 2 # Отсчет начинается со 2 строки в таблице
    end
    nil
  end

  def session
    build_session
    yield
    @worksheets.map(&:save)
  end

  private

  def build_session
    @session = GoogleDrive::Session.from_service_account_key(@service_account_key_json)
    @spreadsheet = @session.spreadsheet_by_key(@spreadsheet_key)
    @worksheets = @spreadsheet.worksheets
  end

  def worksheet
    build_session if @worksheets.blank?

    @worksheets[@worksheet_num]
  end
end