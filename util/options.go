package patchwork

const (
	DefaultBranchMode = iota
	UseLocalMode
	UseRemoteMode
)

type Options struct {
	CurrentPath             string
	ReleaseBranch           string
	ForceResetReleaseBranch bool

	// The remote name, default is origin(remotes/origin)
	RemoteName string

	// Use branch mode
	UseRemote  bool
	UseLocal   bool
	BranchMode int

	// Just used for internal
	GitVersion  string
	AGitVersion string

	ApplyTo string

	// User custom folder for patch generate
	PatchFolder string

	// Add number at the beginning of patch files name
	PatchNumber bool
}
