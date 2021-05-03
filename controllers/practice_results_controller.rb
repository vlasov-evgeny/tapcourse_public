class PracticeResultsController < ApplicationController
  include EditorJsController
  before_action :set_practice_result, only: [:start_check, :show, :complete_check, :update, :return_on_check]

  def update
    # TODO: Добавить проверку policy
    authorize @practice_result, :check?
    @practice_result.update(practice_result_params)
    render :summary
  end

  def show
    authorize @practice_result
    @tasks = @practice_result.practice.tasks
    @course_module_unit = @practice_result.practice.course_module_unit
    @course = @course_module_unit.course_module.course
  end

  def complete_check
    authorize @practice_result
    @practice_result.submit!(params[:state])
    render :summary
  end

  def return_on_check
    authorize @practice_result
    @practice_result.return_on_check!
    render :summary
  end

  def start_check
    authorize @practice_result
    @practice_result.start_check!(current_user)
    render :summary
  end

  # Методы для функционала проверки практических работ

  def course_list
    @courses = Course.find_by_sql [%{
      SELECT courses.*, COUNT(results.id) AS answers_awaiting_checking_count FROM courses
      LEFT JOIN course_modules ON course_modules.course_id = courses.id
      LEFT JOIN (
        SELECT * FROM course_module_units WHERE course_module_units.unit_type = ?
      ) units ON units.course_module_id = course_modules.id
      LEFT JOIN practices ON units.unit_content_id = practices.id
      LEFT JOIN (
        SELECT practice_results.* FROM practice_results
        WHERE practice_results.state = ? AND practice_results.mentor_id IS NULL
      ) results ON practices.id = results.practice_id
      GROUP BY courses.id
      ORDER BY answers_awaiting_checking_count DESC
    }, CourseModuleUnitType::PRACTICE, PracticeState::ON_CHECK]
  end

  def course_practice_list
    @course = Course.find(params[:course_id])
    @units = CourseModuleUnit.find_by_sql([%{
      SELECT course_module_units.*, units_stats.count AS answers_awaiting_checking_count
      FROM (
          SELECT units.id, COUNT(results.id)
          FROM courses
          LEFT JOIN course_modules ON course_modules.course_id = courses.id
          LEFT JOIN (
          SELECT * FROM course_module_units WHERE course_module_units.unit_type = ?
          ) units ON units.course_module_id = course_modules.id
          LEFT JOIN practices ON units.unit_content_id = practices.id
          LEFT JOIN (
          SELECT * FROM practice_results WHERE practice_results.state = ? AND practice_results.mentor_id IS NULL
          ) results ON practices.id = results.practice_id
          WHERE courses.id = ?
          GROUP BY units.id
      ) units_stats
      LEFT JOIN course_module_units ON course_module_units.id = units_stats.id
      ORDER BY answers_awaiting_checking_count DESC
     }, CourseModuleUnitType::PRACTICE, PracticeState::ON_CHECK, params[:course_id]]).select { |unit| unit.id.present? }
  end

  def course_practice_answer_list
    @course = Course.find(params[:course_id])
    @unit = CourseModuleUnit.find(params[:unit_id])
    @users_answers = PracticeResult.find_by_sql [%{
      SELECT units.*, practice_results.*, users.*,
        practice_results.id AS practice_result_id, units.deadline as deadline
      FROM(
          SELECT course_module_units.*
          FROM course_module_units
          WHERE course_module_units.id = ?
      ) units
      LEFT JOIN practices ON units.unit_content_id = practices.id
      LEFT JOIN practice_results ON practices.id = practice_results.practice_id
      LEFT JOIN users ON users.id = practice_results.user_id
      WHERE users.id IS NOT NULL AND practice_results.state <> ?
      ORDER BY practice_results.completion_time DESC
     }, @unit.id, PracticeState::IN_PROGRESS]
  end

  private

  # Обновляет записи о начислении баллов для пользователя.
  def upsert_user_score
    user_score = UserScore.find_by(user: @practice_result.user,
                                   course: @practice_result.course,
                                   source: @practice_result)
    if user_score.nil?
      UserScore.create!(score: @practice_result.score,
                        user: @practice_result.user,
                        course: @practice_result.course,
                        author: @practice_result.mentor,
                        source: @practice_result)
    else
      user_score.update!(score: @practice_result.score, author: @practice_result.mentor)
    end
  end

  def set_practice_result
    @practice_result = PracticeResult.find(params[:id])
  end

  def set_practice
    @practice = Practice.find(params[:practice_id])
  end

  def set_course
    @course = Course.find(params[:course_id])
  end

  def practice_result_params
    params.permit(review: {})
  end

  def set_editor_js_model
    set_practice_result
    @editor_js_object = @practice_result
  end
end
