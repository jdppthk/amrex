!! Provides access to a plotfiles as generated by legacy _AMRLib_ applications.
module plotfile_module

  use bl_error_module
  use bl_space
  use box_module
  use fabio_module

  implicit none

  integer, parameter :: MAX_PATH_NAME = 128
  integer, parameter :: MAX_VAR_NAME  = 20

  interface destroy
     module procedure plotfile_destroy
  end interface destroy

  interface build
     module procedure plotfile_build
  end interface build

  type plotfile_fab
     private
     integer :: dim = 0
     character(len=MAX_PATH_NAME) :: filename = ""
     integer :: offset = 0
     integer :: size = 0
     type(box) :: bx
     integer :: nc = 0, ng = 0
     real(kind=dp_t), pointer, dimension(:) :: mx => Null(), mn => Null()
     real(kind=dp_t), pointer, dimension(:,:,:,:) :: p => Null()
  end type plotfile_fab

  type plotfile_grid
     private
     integer :: dim = 0
     integer :: nboxes = 0
     character(len=MAX_PATH_NAME) :: fileprefix = ""
     character(len=MAX_PATH_NAME) :: header = ""
     real(kind=dp_t), pointer :: plo(:,:) => Null()
     real(kind=dp_t), pointer :: phi(:,:) => Null()
     type(plotfile_fab), pointer :: fabs(:) => Null()
     type(box) :: pdbx
     real(kind=dp_t), pointer :: dxlev(:) 
  end type plotfile_grid

  type plotfile
     integer :: dim = 0
     character(len=MAX_PATH_NAME) :: root = ""
     character(len=MAX_VAR_NAME), pointer :: names(:) => Null()
     integer :: nvars = 0
     type(plotfile_grid), pointer :: grids(:) => Null()
     integer :: flevel = 0
     real(kind=dp_t) :: tm
     integer, pointer :: refrat(:,:) => Null()
     real(kind=dp_t), pointer :: phi(:)
     real(kind=dp_t), pointer :: plo(:)
  end type plotfile

  interface nboxes
     module procedure plotfile_nboxes_n
     module procedure plotfile_nboxes
  end interface

  interface get_box
     module procedure plotfile_get_box
  end interface

  interface dataptr
     module procedure plotfile_dataptr
  end interface

  interface nvars
     module procedure plotfile_nvars
  end interface

  interface var_name
     module procedure plotfile_var_name
  end interface

contains

  function plotfile_dim(pf) result(r)
    integer :: r
    type(plotfile), intent(in) :: pf
    r = pf%dim
  end function plotfile_dim

  function plotfile_var_name(pf, n) result(r)
    character(len=MAX_VAR_NAME) :: r
    type(plotfile), intent(in) :: pf
    integer, intent(in) :: n
    r = pf%names(n)
  end function plotfile_var_name

  function plotfile_refrat_n(pf, n) result(r)
    type(plotfile), intent(in) :: pf
    integer, intent(in) :: n
    integer :: r(pf%dim)
    if ( n < 1 .or. n >= pf%flevel) &
         call bl_error("PLOTFILE_REFRAT_N: out of bounds: ", n)
    r = pf%refrat(n,:)
  end function plotfile_refrat_n

  function plotfile_refrat(pf) result(r)
    type(plotfile), intent(in) :: pf
    integer :: r(pf%flevel-1,pf%dim)
    r = pf%refrat
  end function plotfile_refrat

  function plotfile_time(pf) result(r)
    type(plotfile), intent(in) :: pf
    real(kind=dp_t) :: r
    r = pf%tm
  end function plotfile_time

  function plotfile_dataptr(pf, n, i) result(r)
    real(kind=dp_t), pointer :: r(:,:,:,:)
    type(plotfile), intent(in) :: pf
    integer, intent(in) :: n, i
    r => pf%grids(n)%fabs(i)%p
  end function plotfile_dataptr

  function plotfile_get_pd_box(pf, n) result(r)
    type(box) :: r
    type(plotfile), intent(in) :: pf
    integer, intent(in) :: n
    r = pf%grids(n)%pdbx
  end function plotfile_get_pd_box

  function plotfile_get_dx(pf, n) result(r)
    type(plotfile), intent(in) :: pf
    integer, intent(in) :: n
    real(kind=dp_t) :: r(pf%dim)
    r = pf%grids(n)%dxlev
  end function plotfile_get_dx

  function plotfile_get_box(pf, n, i) result(r)
    type(box) :: r
    type(plotfile), intent(in) :: pf
    integer, intent(in) :: n, i
    r = pf%grids(n)%fabs(i)%bx
  end function plotfile_get_box

  function plotfile_nboxes_n(pf, n) result(r)
    integer :: r
    type(plotfile), intent(in) :: pf
    integer, intent(in) :: n
    r = pf%grids(n)%nboxes
  end function plotfile_nboxes_n

  function plotfile_nboxes(pf) result(r)
    type(plotfile), intent(in) :: pf
    integer :: r(pf%flevel)
    integer :: n
    r = (/(pf%grids(n)%nboxes, n=1, pf%flevel)/)
  end function plotfile_nboxes

  function plotfile_maxval(pf, n, i) result(r)
    type(plotfile), intent(in) :: pf
    integer, intent(in) :: n
    integer, intent(in) :: i
    real(kind=dp_t) :: r
    integer j
    r = -huge(r)
    do j = 1, pf%grids(i)%nboxes
       r = max(r, pf%grids(i)%fabs(j)%mx(n))
    end do
  end function plotfile_maxval

  function plotfile_minval(pf, n, i) result(r)
    type(plotfile), intent(in) :: pf
    integer, intent(in) :: i, n
    real(kind=dp_t) :: r
    integer j
    r = huge(r)
    do j = 1, pf%grids(i)%nboxes
       r = min(r, pf%grids(i)%fabs(j)%mn(n))
    end do
  end function plotfile_minval

  function plotfile_nlevels(pf) result(r)
    integer :: r
    type(plotfile), intent(in) :: pf
    r = pf%flevel
  end function plotfile_nlevels

  function plotfile_nvars(pf) result(r)
    integer :: r
    type(plotfile), intent(in) :: pf
    r = pf%nvars
  end function plotfile_nvars

  subroutine plotfile_build(pf, root, unit, verbose)
    use bl_stream_module
    use bl_IO_module
    type(plotfile), intent(out) :: pf
    character(len=*), intent(in) :: root
    integer, intent(in), optional :: unit
    logical, intent(in), optional :: verbose
    character(len=MAX_PATH_NAME) :: str
    integer :: lun
    type(bl_stream) :: strm
    logical :: lverbose

    ! deferred functionality
    lverbose = .false.; if ( present(verbose) ) lverbose = verbose
    pf%root = root
    call build(strm, unit)
    lun = bl_stream_the_unit(strm)
    open(unit=lun, &
         file = trim(pf%root) // "/" // "Header", &
         status = 'old', action = 'read')
    read(unit=lun,fmt='(a)') str
    if ( str == '&PLOTFILE' ) then
       call build_pf
    else if ( str == 'NavierStokes-V1.1' .or. str == 'HyperCLaw-V1.1' ) then 
       call build_ns_plotfile
    else
       call bl_error('BUILD_PLOTIFILE: Header has improper magic string', str)
    end if
    call destroy(strm)

  contains

    !! This one will use namelist I/O to read the header information
    subroutine build_pf
      call bl_error("PLOTFILE_BUILD: not implemented")
    end subroutine build_pf

    ! NavierStokes-V1.1 Plotfile Formats
    ! Record
    !     : c : NavierStokes-V1.1/HyperClaw-V1.1
    !     : c : Numbers of fields = n
    !    n: i : Field Names
    !     : i : Dimension = dm
    !     : r : Time
    !     : i : Number of Levels - 1 : nl
    !     : r : Physical domain lo end [1:dm]
    !     : r : Physical domain hi end [1:dm]
    !     : i : Refinement Ratios [1:nl-1]
    !     : b : Prob domains per level [1:nl]
    !     : i : unused [1:nl]
    !   nl: r : grid spacing, per level, [1:dm]
    !     : i : unused  :
    !     : i : unused
    !     For each level
    !     [
    !       : iiri : dummy, nboxes, dummy, dummy
    !       For each box, j
    !       [
    !         : r :  plo[1:dm,j], phi[1:dm, j]
    !       ]
    !       : c : level directory
    !     ]
    !     Close Header File
    !     For each level
    !     [
    !       Open Header of sub-directory
    !       : iiii: dummy, dummy, ncomponents, dummy
    !       : i ; '(', nboxes dummy
    !       For each box, j
    !       [
    !         : b : bx[j]
    !       ]
    !       :  : ')'
    !       For each box, j
    !       [
    !         : ci : 'FabOnDisk: ' Filename[j], Offset[j]
    !       ]
    !       : i : nboxes, ncomponents
    !       For each box, j
    !       [
    !         : r : min[j]
    !       ]
    !       : i : nboxes, ncomponents
    !       For each box, j
    !       [
    !         : r : man[j]
    !       ]
    !       Close subgrid file
    !     ]

    subroutine build_ns_plotfile()
      integer :: i, n
      integer :: j, nc
      integer n1
      character(len=MAX_PATH_NAME) :: str, str1, cdummy
      integer :: idummy
      real(kind=dp_t) :: rdummy

      read(unit=lun,fmt=*) pf%nvars
      allocate(pf%names(pf%nvars))
      do i = 1, pf%nvars
         read(unit=lun,fmt='(a)') pf%names(i)
      end do
      read(unit=lun, fmt=*) pf%dim
      read(unit=lun, fmt=*) pf%tm
      read(unit=lun, fmt=*) pf%flevel
      pf%flevel = pf%flevel + 1

      allocate(pf%grids(pf%flevel), pf%plo(pf%dim), pf%phi(pf%dim))

      read(unit=lun, fmt=*) pf%plo, pf%phi
      !! Not make this really work correctly, I need to see if these are
      !! IntVects here.  I have no examples of this.
      allocate(pf%refrat(pf%flevel-1,1:pf%dim))
      read(unit=lun, fmt=*) pf%refrat(:,1)
      pf%refrat(:,2:pf%dim) = spread(pf%refrat(:,1), dim=2, ncopies=pf%dim-1)

      do i = 1, pf%flevel
         call box_read(pf%grids(i)%pdbx, unit = lun)
      end do
      read(unit=lun, fmt=*) (idummy, i=1, pf%flevel)
      do i = 1, pf%flevel
         allocate(pf%grids(i)%dxlev(pf%dim))
         read(unit=lun, fmt=*) pf%grids(i)%dxlev
      end do

      read(unit=lun, fmt=*) idummy, idummy
      do i = 1, pf%flevel
         read(unit=lun, fmt=*) idummy, pf%grids(i)%nboxes, rdummy, idummy
         allocate(pf%grids(i)%plo(pf%dim, pf%grids(i)%nboxes))
         allocate(pf%grids(i)%phi(pf%dim, pf%grids(i)%nboxes))
         allocate(pf%grids(i)%fabs(pf%grids(i)%nboxes))
         do j = 1, pf%grids(i)%nboxes
            read(unit=lun, fmt=*) pf%grids(i)%plo(:, j), pf%grids(i)%phi(:,j)
         end do
         read(unit=lun, fmt='(a)') str
         str1 = str(:index(str, "/")-1)
         pf%grids(i)%fileprefix = str1
         str1 = trim(str(index(str, "/")+1:)) // "_H"
         pf%grids(i)%header = trim(str1)
      end do
      close(unit=lun)
      do i = 1, pf%flevel
         open(unit=lun, &
              action = 'read', &
              status = 'old', file = trim(trim(pf%root) // "/" //  &
              trim(pf%grids(i)%fileprefix) // "/" // &
              trim(pf%grids(i)%header)) )
         read(unit=lun, fmt=*) idummy, idummy, nc, idummy
         if ( nc /= pf%nvars ) &
              call bl_error("BUILD_PLOTFILE: unexpected nc", nc)
         call bl_stream_expect(strm, '(')
         n = bl_stream_scan_int(strm)
         if ( n /= pf%grids(i)%nboxes ) &
              call bl_error("BUILD_PLOTFILE: unexpected n", n)
         idummy = bl_stream_scan_int(strm)
         do j = 1, pf%grids(i)%nboxes
            call box_read(pf%grids(i)%fabs(j)%bx, unit = lun)
            pf%grids(i)%fabs(j)%size = volume(pf%grids(i)%fabs(j)%bx)
            pf%grids(i)%fabs(j)%nc = nc
         end do
         call bl_stream_expect(strm, ')')
         read(unit=lun, fmt=*) idummy
         do j = 1, pf%grids(i)%nboxes
            read(unit=lun, fmt=*) cdummy, &
                 pf%grids(i)%fabs(j)%filename, pf%grids(i)%fabs(j)%offset
         end do
         do j = 1, pf%grids(i)%nboxes
            allocate(pf%grids(i)%fabs(j)%mx(nc))
            allocate(pf%grids(i)%fabs(j)%mn(nc))
         end do
         read(unit=lun, fmt=*) n, n1
         if ( n /= pf%grids(i)%nboxes) call bl_error('BUILD_PLOTFILE: confused1')
         if ( n1 /= nc ) call bl_error('BUILD_PLOTFILE: confused2')
         do j = 1, pf%grids(i)%nboxes
            read(unit=lun, fmt=*) pf%grids(i)%fabs(j)%mn
         end do
         read(unit=lun, fmt=*) n, n1
         if ( n /= pf%grids(i)%nboxes) call bl_error('BUILD_PLOTFILE: confused3')
         if ( n1 /= nc ) call bl_error('BUILD_PLOTFILE: confused4')
         do j = 1, pf%grids(i)%nboxes
            read(unit=lun, fmt=*) pf%grids(i)%fabs(j)%mx
         end do
         close(unit=lun)
      end do
    end subroutine build_ns_plotfile
  end subroutine plotfile_build

  subroutine plotfile_destroy(pf)
    type(plotfile), intent(inout) :: pf
    integer :: i, j

    do i = 1, pf%flevel
       deallocate(pf%grids(i)%plo, pf%grids(i)%phi, pf%grids(i)%dxlev)
       do j = 1, size(pf%grids(i)%fabs)
          deallocate(pf%grids(i)%fabs(j)%mn, pf%grids(i)%fabs(j)%mx)
          if ( associated(pf%grids(i)%fabs(j)%p) ) &
               deallocate(pf%grids(i)%fabs(j)%p)
       end do
       deallocate(pf%grids(i)%fabs)
    end do
    deallocate(pf%refrat)
    deallocate(pf%names)
    deallocate(pf%grids)
    deallocate(pf%plo, pf%phi)
  end subroutine plotfile_destroy

  subroutine fab_bind_level_comp(pf, i, c)
    type(plotfile), intent(inout) :: pf
    integer, intent(in) :: i, c
    integer :: j
    do j = 1, pf%grids(i)%nboxes
       call fab_bind_comp(pf, i, j, c)
    end do
  end subroutine fab_bind_level_comp

  subroutine fab_bind_level_comp_vec(pf, i, c)
    type(plotfile), intent(inout) :: pf
    integer, intent(in) :: i, c(:)
    integer :: j
    do j = 1, pf%grids(i)%nboxes
       call fab_bind_comp_vec(pf, i, j, c)
    end do
  end subroutine fab_bind_level_comp_vec

  subroutine fab_bind_level(pf, i)
    type(plotfile), intent(inout) :: pf
    integer, intent(in) :: i
    integer :: j
    do j = 1, pf%grids(i)%nboxes
       call fab_bind(pf, i, j)
    end do
  end subroutine fab_bind_level

  subroutine fab_unbind_level(pf, i)
    type(plotfile), intent(inout) :: pf
    integer, intent(in) :: i
    integer :: j
    do j = 1, pf%grids(i)%nboxes
       call fab_unbind(pf, i, j)
    end do
  end subroutine fab_unbind_level

  subroutine fab_bind(pf, i, j)
    type(plotfile), intent(inout) :: pf
    integer, intent(in) :: i, j
    integer fd
    integer :: lo(MAX_SPACEDIM), hi(MAX_SPACEDIM), nc

    if ( i < 0 .or. i > pf%flevel ) &
         call bl_error('fab_bind: level out of bounds')
    if ( j < 0 .or. j > pf%grids(i)%nboxes ) &
         call bl_error('fab_bind: grid out of bounds')
    call fabio_open(fd,                         &
         trim(pf%root) // "/" //                &
         trim(pf%grids(i)%fileprefix) // "/" // &
         trim(pf%grids(i)%fabs(j)%filename))
    lo = 1
    hi = 1
    nc = pf%nvars
    lo(1:pf%dim) = lwb(pf%grids(i)%fabs(j)%bx)
    hi(1:pf%dim) = upb(pf%grids(i)%fabs(j)%bx)
    allocate(pf%grids(i)%fabs(j)%p(lo(1):hi(1), lo(2):hi(2), lo(3):hi(3), nc))
    call fabio_read_d(fd,              &
         pf%grids(i)%fabs(j)%offset,   &
         pf%grids(i)%fabs(j)%p(:,:,:,:), &
         pf%grids(i)%fabs(j)%size*pf%nvars)
    call fabio_close(fd)

  end subroutine fab_bind

  subroutine fab_bind_comp(pf, i, j, c)
    type(plotfile), intent(inout) :: pf
    integer, intent(in) :: i, j, c

    call fab_bind_comp_vec(pf, i, j, (/c/))

  end subroutine fab_bind_comp

  subroutine fab_bind_comp_vec(pf, i, j, c)
    type(plotfile), intent(inout) :: pf
    integer, intent(in) :: i, j, c(:)
    integer :: n
    integer :: fd
    integer :: lo(MAX_SPACEDIM), hi(MAX_SPACEDIM)

    call fabio_open(fd,                         &
         trim(pf%root) // "/" //                &
         trim(pf%grids(i)%fileprefix) // "/" // &
         trim(pf%grids(i)%fabs(j)%filename))
    lo = 1
    hi = 1
    lo(1:pf%dim) = lwb(pf%grids(i)%fabs(j)%bx)
    hi(1:pf%dim) = upb(pf%grids(i)%fabs(j)%bx)
    allocate(pf%grids(i)%fabs(j)%p(lo(1):hi(1), lo(2):hi(2), lo(3):hi(3), size(c)))
    do n = 1, size(c)
       call fabio_read_skip_d(fd,              &
            pf%grids(i)%fabs(j)%offset,        &
            pf%grids(i)%fabs(j)%size*(c(n)-1), &
            pf%grids(i)%fabs(j)%p(:,:,:,n),    &
            pf%grids(i)%fabs(j)%size)
    end do
    call fabio_close(fd)

  end subroutine fab_bind_comp_vec

  subroutine fab_unbind(pf, i, j)
    type(plotfile), intent(inout) :: pf
    integer, intent(in) :: i, j
    if ( associated(pf%grids(i)%fabs(j)%p) ) deallocate(pf%grids(i)%fabs(j)%p)
  end subroutine fab_unbind

end module plotfile_module
