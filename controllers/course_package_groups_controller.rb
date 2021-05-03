class CoursePackageGroupsController < ApplicationController
  before_action :set_course, only: [:index, :create]
  before_action :set_course_package_group, only: [:show, :edit, :update, :destroy, :members]

  # GET /courses/:course_id/course_package_groups
  def index
    @course_packages = policy_scope(CoursePackage).order(:price)
                           .where(course_package_groups: { course_id: @course.id })
    if CoursePackageGroupPolicy.new(current_user).index?
      @course_package_groups = policy_scope(@course.course_package_groups)
    else
      @course_package_groups = CoursePackageGroup
                                   .where(id: @course_packages.map(&:course_package_group_id).uniq)
                                   .order(:start_date)
    end
    @cache = { course_packages: @course_packages }
  end

  # POST /courses/:course_id/course_package_groups
  def create
    @course_package_group = @course.course_package_groups.build(course_package_group_params)
    authorize @course_package_group
    @course_package_group.save
    render :show
  end

  # GET /course_package_groups/:id
  def show
    authorize @course_package_group
  end

  # GET /course_package_groups/:id/edit
  def edit
    authorize @course_package_group
  end

  # PUT /course_package_groups/:id
  def update
    authorize @course_package_group
    @course_package_group.update(course_package_group_params)
    render :show
  end

  # DELETE /course_package_groups/:id
  def destroy
    authorize @course_package_group
    @course_package_group.destroy
    head :no_content
  end

  def members
    authorize @course_package_group
    @course_packages = CoursePackage.where(id: params[:course_package_ids])
    @users = @course_package_group.members(@course_packages).search_by_query(params[:query]).order(:name, :last_name)
    set_pagination_meta(total: @users.count)
    @users = @users.paginate(page: page, per_page: per_page)
    render 'users/index'
  end

  private

  def course_package_group_params
    params.require(:course_package_group).permit(:name, :published, :start_date, :end_date)
  end

  def set_course_package_group
    @course_package_group = CoursePackageGroup.find(params[:id])
  end

  def set_course
    @course = Course.find(params[:course_id])
  end

  def default_per_page
    100
  end
end