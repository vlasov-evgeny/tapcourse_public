class UsersController < ApplicationController
  PER_PAGE = 50
  skip_before_action :authorize_request, only: :index
  before_action :set_user, only: [:show, :role, :reset_role]
  before_action :set_course, only: [:show]

  # GET /users?page=1&course_id=1&query=name_of_user
  def index
    @users = if params[:course_id]
               User.where('courses.id' => params[:course_id])
             else
               User.all
             end
    @users = @users.search_by_query(params[:query]).order(:name, :last_name)
    set_pagination_meta(total: @users.count)
    @users = @users.paginate(page: params[:page], per_page: PER_PAGE)
  end

  # GET /users/:id?course_id=1
  def show
    @courses = if params[:course_id].nil?
                 @user.courses
               else
                 @user.courses.where(id: params[:course_id]).limit(1)
               end
    @course_results_by_courses_id = @user.user_course_results.where(course: @courses).group_by(&:course_id)
    @subscriptions_by_courses_id = @user.course_subscriptions
                                       .where(course: @courses, end_date: Date.today..Float::INFINITY)
                                       .group_by(&:course_id)
    @clans_by_courses_id = @user.clans.where(course: @courses).group_by(&:course_id)
  end

  # GET /courses/:id/courses
  def courses
    @courses = @user.courses
    json_response(@courses)
  end

  # PUT /users/:id/role
  def role
    authorize User
    @user.update(role: params[:role])
    head :no_content
  end

  # DELETE /users/:id/role
  def reset_role
    @user.reset_role!
    head :no_content
  end

  def staff
    authorize User
    @users = User.staff
    render :index
  end

  def register_by_vk
    authorize User
    @user = User.register_by_vk(VkApi.extract_vk_id(params[:url])[:vk_id])
    render :show
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def set_course
    @course = if params[:course_id].nil?
                nil
              else
                Course.find(params[:course_id])
              end
  end
end
