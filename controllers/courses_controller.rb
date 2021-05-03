class CoursesController < ApplicationController
  before_action :set_course, only: [:show, :edit, :update, :destroy, :landing, :copy_modules,
                                    :remove_image, :set_image, :sync_tilda, :summary_results]
  before_action :find_or_create_category, only: [:create, :update]

  # GET /courses?category_id=3&subcategory_id=5
  def index
    authorize Course
    @courses = policy_scope(Course.includes(:course_category).includes(:course_package_groups))
    if params[:category_id] && params[:subcategory_id].nil?
      @courses = @courses.where('course_categories.parent_id = ?', params[:category_id])
                     .references(:course_categories)
    elsif params[:subcategory_id]
      @courses = @courses.where(course_category_id: params[:subcategory_id])
    end
    @cache = CoursePolicy.make_cache(@current_user)
  end

  # POST /courses
  def create
    authorize Course
    @course = Course.new(course_params)
    @course.course_category = @category unless @category.nil?
    @course.save
    render :show
  end

  # GET /courses/:id
  def show
    authorize @course
  end

  # GET /courses/:id/landing
  def landing
    authorize @course
    render :show
  end

  # GET /courses/:id/edit
  def edit
    authorize @course
  end

  # PUT /courses/:id
  def update
    authorize @course
    @course.assign_attributes(course_params)
    @course.course_category = @category unless @category.nil?
    @course.save
    render :show
  end

  # DELETE /courses/:id
  def destroy
    authorize @course
    @course.destroy
    head :no_content
  end

  # DELETE /courses/:id/image
  def remove_image
    authorize @course, :update?
    @course.image.purge
    render body: nil, status: :ok
  end

  # POST /courses/:id/image
  # Content-Type: multipart/form-data;boundary=Boundary
  # Form-data: param image is an image for uploading
  def set_image
    authorize @course, :update?
    @course.image.attach(helpers.resize_image(params[:image], '400x400'))
    @course.save
    render body: nil, status: :ok
  end

  def sync_tilda
    authorize @course, :update?
    TildaWorker.perform_async(TildaWorker::SYNC_PAGE, @course.tilda_page_id)
  end

  def my_courses
    @courses = []
    @courses = Course.user_courses(current_user) unless current_user.id.nil?
  end

  def summary_results
    authorize @course
    @course_package_group = CoursePackageGroup.find(params[:course_package_group_id])
    @users = @course_package_group.members.search_by_query(params[:query]).order(:name, :last_name)
    set_pagination_meta(total: @users.count)
    @users = @users.paginate(page: page, per_page: per_page)
    @results_summary = @course.results_summary(@users, @course_package_group)
    @course_module_units = @course_package_group.course_module_units.where(published: true)
  end

  def copy_modules
    authorize @course, :update?
    CourseModule.where(id: params[:course_module_ids]).each do |course_module|
      course_module.create_copy(@course).save
    end
    head :ok
  end

  private

  def find_or_create_category
    @category = nil
    unless params.dig(:course, :category_id).nil?
      @category = CourseCategory.find(params.dig(:course, :category_id))
      return
    end
    if params.dig(:course, :new_subcategory, :parent_id).nil? &&
        !params.dig(:course, :new_subcategory, :name).nil?
      main_category = CourseCategory.where('lower(name) = ?',
                                       params.dig(:course, :new_category, :name).downcase).first
      main_category ||= CourseCategory.new(name: params.dig(:course, :new_category, :name))
    elsif !params.dig(:course, :new_subcategory, :parent_id).nil?
      main_category = CourseCategory.find(params.dig(:course, :new_subcategory, :parent_id))
    else
      return
    end
    subcategory = CourseCategory.new(params.require(:course).require(:new_subcategory).permit(:name))
    subcategory.parent = main_category
    @category = CourseCategory.where('lower(name) = ? AND parent_id = ?',
                                     subcategory.name.downcase,
                                     subcategory.parent_id).first
    @category ||= subcategory
    @category.save
  end

  def course_params
    params.require(:course).permit(:name, :description, :published, :lives, :teacher_id,
                                   mentor_ids: [],
                                   course_category_attributes: [:name, parent_attributes: [:name]],
                                   settings: [
                                       integrations: [
                                           tilda: [:active, :page_id],
                                           telegram: [:active, :teacher_bot_url]
                                       ]
                                   ])
  end

  def set_course
    @course = Course.find(params[:id])
  end

  def default_per_page
    50
  end
end
