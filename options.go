package agit_release

type Options struct {
	CurrentPath      string
	ReleaseBranch    string
	GitTargetVersion string

	// The remote name, default is origin(remotes/origin)
	RemoteName string
	UseRemote  bool

	// Just used for internal
	GitVersion  string
	AGitVersion string
}
